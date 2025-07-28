//
//  ChatMessage.swift
//  Local LLM Chat
//
//  Created by derham on 7/12/25.
//

import Foundation

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}


// MARK: - LLM API Request Models
struct LLMAPIRequest: Codable {
    let model: String
    let messages: [LLMMessage]
    let stream: Bool
    
    
    init(model: String, messages: [LLMMessage], stream: Bool = false) {
        self.model = model
        self.messages = messages
        self.stream = stream
    }
}


struct LLMMessage: Codable {
    let role: String
    let content: String
}

// MARK: - LLM API Response Models
struct LLMAPIResponse: Codable {
    let choices: [LLMChoice]
}

struct LLMChoice: Codable {
    let message: LLMMessage
}
