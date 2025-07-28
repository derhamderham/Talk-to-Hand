//
//  ChatManager.swift
//  Local LLM Chat
//
//  Created by derham on 7/12/25.
//

import Foundation
import Combine
import CoreData

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingHistory = false
    @Published var hasMoreHistory = true
    @Published var isBotTyping: Bool = false
    
    // Streaming properties
    @Published var currentStreamingMessage: ChatMessage?
    @Published var isStreaming: Bool = false
    
    // Pagination properties
    private let messagesPerPage = 20
    private let historyManager = ChatHistoryManager.shared
    private var currentPage = 0
    private var allMessages: [ChatMessage] = []
    
    // Settings - directly refer to the shared SettingsManager
    @Published var serverURL: String {
        didSet { SettingsManager.shared.serverURL = serverURL }
    }
    @Published var apiKey: String {
        didSet { SettingsManager.shared.apiKey = apiKey }
    }
    @Published var modelName: String {
        didSet { SettingsManager.shared.modelName = modelName }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    private let session = URLSession.shared
    
    init() {
        self.serverURL = SettingsManager.shared.serverURL
        self.apiKey = SettingsManager.shared.apiKey
        self.modelName = SettingsManager.shared.modelName
    }
    
    // Load initial messages (most recent)
    func loadInitialMessages() {
        currentPage = 0
        _ = max(0, allMessages.count - messagesPerPage)
        messages = historyManager.fetch()
        hasMoreHistory = allMessages.count > messagesPerPage
    }
    
    // Load older messages (pagination)
    func loadMoreHistory() async {
        guard hasMoreHistory && !isLoadingHistory else { return }
        isLoadingHistory = true
        // Pagination logic goes here (if needed)
        isLoadingHistory = false
    }
    
    // Send a message and handle streaming response
    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(text: text, isUser: true)
        allMessages.append(userMessage)
        messages.append(userMessage)
        
        // Show typing bubble FIRST - don't add empty message yet
        isBotTyping = true
        isLoading = true
        isStreaming = false
        
        defer {
            isLoading = false
            isStreaming = false
            isBotTyping = false
            currentStreamingMessage = nil
        }
        
        do {
            try await streamLLMResponse(message: text)
        } catch {
            let errorMessage = ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false)
            allMessages.append(errorMessage)
            messages.append(errorMessage)
        }
        
        historyManager.save(messages: messages)
    }
    
    // Streaming LLM API call
    private func streamLLMResponse(message: String) async throws {
        guard let url = URL(string: "\(serverURL)/v1/chat/completions") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let requestBody = LLMAPIRequest(
            model: modelName,
            messages: [LLMMessage(role: "user", content: message)],
            stream: true
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        var accumulatedText = ""
        var hasCreatedMessage = false
        
        for try await line in asyncBytes.lines {
            // Skip empty lines and non-data lines
            guard line.hasPrefix("data: ") else { continue }
            
            let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
            
            // Check for end of stream
            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                break
            }
            
            // Parse the JSON chunk
            guard let data = jsonString.data(using: .utf8) else { continue }
            
            do {
                let streamResponse = try JSONDecoder().decode(StreamingResponse.self, from: data)
                
                if let content = streamResponse.choices.first?.delta.content {
                    // Create empty message when we get first content
                    if !hasCreatedMessage {
                        await MainActor.run {
                            let botMessage = ChatMessage(text: "", isUser: false)
                            self.allMessages.append(botMessage)
                            self.messages.append(botMessage)
                            self.currentStreamingMessage = botMessage
                            self.isBotTyping = false  // Turn off typing bubble
                            self.isStreaming = true   // Start streaming
                        }
                        hasCreatedMessage = true
                    }
                    
                    accumulatedText += content
                    
                    // Update the streaming message in real-time
                    await MainActor.run {
                        if let lastIndex = messages.lastIndex(where: { !$0.isUser }) {
                            let cleanedText = cleanLLMResponse(accumulatedText)
                            let updatedMessage = ChatMessage(text: cleanedText, isUser: false)
                            messages[lastIndex] = updatedMessage
                            allMessages[allMessages.count - 1] = updatedMessage
                            currentStreamingMessage = updatedMessage
                        }
                    }
                    
                    // Add a small delay to make the streaming visible
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
                }
            } catch {
                // Skip malformed JSON chunks
                continue
            }
        }
    }
    
    // Fallback non-streaming API call (for servers that don't support streaming)
    private func callLLMAPI(message: String) async throws -> String {
        guard let url = URL(string: "\(serverURL)/v1/chat/completions") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = LLMAPIRequest(
            model: modelName,
            messages: [LLMMessage(role: "user", content: message)],
            stream: false
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let apiResponse = try JSONDecoder().decode(LLMAPIResponse.self, from: data)
        return apiResponse.choices.first?.message.content ?? "No response"
    }
    
    // MARK: - Response Cleaning
    private func cleanLLMResponse(_ response: String) -> String {
        var cleanedResponse = response
        
        // Remove channel tags like <|channel|>analysis<|message|>
        let channelPattern = #"<\|channel\|>[^<]*<\|message\|>"#
        cleanedResponse = cleanedResponse.replacingOccurrences(
            of: channelPattern,
            with: "",
            options: .regularExpression
        )
        
        // Remove other common LLM tags
        let commonTags = [
            #"<\|[^|]*\|>"#,           // Any <|tag|> format
            #"<\|start\|>[^<]*<\|end\|>"#, // Start/end tags
            #"<\|assistant\|>"#,       // Assistant tags
            #"<\|user\|>"#,            // User tags
            #"<\|system\|>"#           // System tags
        ]
        
        for pattern in commonTags {
            cleanedResponse = cleanedResponse.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        // Clean up extra whitespace
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedResponse
    }
    
    func clearMessages() {
        messages.removeAll()
        allMessages.removeAll()
        currentPage = 0
        hasMoreHistory = true
    }
}

// MARK: - API Request/Response Structures


// Streaming response structures
struct StreamingResponse: Codable {
    let choices: [StreamingChoice]
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
}

struct StreamingChoice: Codable {
    let delta: StreamingDelta
    let index: Int?
    let finish_reason: String?
}

struct StreamingDelta: Codable {
    let content: String?
    let role: String?
}

// MARK: - Error Handling

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case requestTimedOut
    case streamingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .requestTimedOut:
            return "The request timed out"
        case .streamingError:
            return "Streaming error occurred"
        }
    }
}
