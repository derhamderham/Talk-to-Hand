//
//  MessageBubble.swift
//  Talk to Hand
//
//  Created by derham on 7/12/25.
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showingCopyAlert = false

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                bubble(isUser: true)
            } else {
                bubble(isUser: false)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func bubble(isUser: Bool) -> some View {
        VStack(alignment: isUser ? .trailing : .leading) {
            Text(message.text)
                .padding(12)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isUser ? .white : .primary)
                .cornerRadius(16)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75,
                       alignment: isUser ? .trailing : .leading)
                .textSelection(.enabled)

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .contextMenu {
            Button("Copy") {
                copyToClipboard(message.text)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showingCopyAlert = true
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}
