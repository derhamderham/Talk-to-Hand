//
//  ChatMessageEntity+Extensions.swift
//  Talk to Hand
//
//  Created by derham on 7/15/25.
//

import Foundation

extension ChatMessageEntity {
    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: self.id ?? UUID(),
            text: self.content ?? "",
            isUser: self.isBotMessage,
            timestamp: self.timestamp ?? Date()
        )
    }
}
