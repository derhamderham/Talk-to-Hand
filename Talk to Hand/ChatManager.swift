//
//  ChatManager.swift
//  Local LLM Chat
//
//  Created by derham on 7/12/25.
//

import Foundation
import Combine

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingHistory = false
    @Published var hasMoreHistory = true
    @Published var isBotTyping: Bool = false

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

    // Send a message and handle response
    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(text: text, isUser: true)
        allMessages.append(userMessage)
        messages.append(userMessage)

        isLoading = true
        isBotTyping = true
        defer {
            isLoading = false
            isBotTyping = false
        }

        do {
            let response = try await callLLMAPI(message: text)
            let botMessage = ChatMessage(text: response, isUser: false)
            allMessages.append(botMessage)
            messages.append(botMessage)
        } catch {
            let errorMessage = ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false)
            allMessages.append(errorMessage)
            messages.append(errorMessage)
        }
        historyManager.save(messages: messages)
    }

    // The actual LLM API call
    private func callLLMAPI(message: String) async throws -> String {
        guard let url = URL(string: "\(serverURL)/v1/chat/completions") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("localhost:1337", forHTTPHeaderField: "Host")

        let requestBody = LLMAPIRequest(
            model: modelName,
            messages: [LLMMessage(role: "user", content: message)]
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

    func clearMessages() {
        messages.removeAll()
        allMessages.removeAll()
        currentPage = 0
        hasMoreHistory = true
    }
}

// Keep the APIError enum as you had:
enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .requestTimedOut:
            return "Error: The request timed out."
        }
    }
}
