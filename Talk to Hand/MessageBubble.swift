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
                VStack(alignment: .trailing) {
                    Text(message.text)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                        .textSelection(.enabled) // Enable text selection
                        .contextMenu {
                            Button("Copy") {
                                copyToClipboard(message.text)
                            }
                        }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading) {
                    Text(message.text)
                        .padding(12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                        .textSelection(.enabled) // Enable text selection
                        .contextMenu {
                            Button("Copy") {
                                copyToClipboard(message.text)
                            }
                        }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showingCopyAlert = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

struct TypingBubble: View {
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(.gray)
                    .opacity(0.7)
                    .offset(y: bounce ? -6 : 0)
                    // Use the delay to stagger each circle's animation:
                    .animation(
                        Animation
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.18),
                        value: bounce
                    )
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .onAppear { bounce = true }
    }
}
