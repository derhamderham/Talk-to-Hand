//
//  ContentView.swift
//  Local LLM Chat
//
//  Created by derham on 7/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var isShowingSettings = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pass focus binding to MessageList for tap-to-dismiss keyboard
                MessageList(
                    chatManager: chatManager,
                    isTextFieldFocused: Binding(
                        get: { isTextFieldFocused },
                        set: { isTextFieldFocused = $0 }
                    )
                )
                InputArea(
                    messageText: $messageText,
                    isTextFieldFocused: $isTextFieldFocused,
                    chatManager: chatManager,
                    sendMessage: sendMessage
                )
            }
            .navigationTitle("Talk to Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(chatManager: chatManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // Keep conversation in focus
            .onAppear {
                chatManager.loadInitialMessages()
                // Auto-focus text field when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Re-focus when app comes back to foreground
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
    }
        
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let userMessage = messageText
        messageText = ""
        
        // Keep focus on input after sending message
        Task {
            await chatManager.sendMessage(userMessage)
            // Re-focus after message is sent for continuous conversation
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
        }
    }
}

struct TypingBubble: View {
    @State private var bounce = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary.opacity(0.8))
                            .frame(width: 8, height: 8)
                            .offset(y: bounce ? -6 : 0)
                            .animation(
                                Animation
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.18),
                                value: bounce
                            )
                    }
                }
                .padding(12)
                .background(Color(.systemGray5))
                .cornerRadius(16)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
            }
            Spacer()
        }
        .onAppear {
            bounce = true
        }
    }
}

private struct MessageList: View {
    @ObservedObject var chatManager: ChatManager
    var isTextFieldFocused: Binding<Bool>

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chatManager.hasMoreHistory {
                        HistoryLoader(chatManager: chatManager)
                    }
                    ForEach(chatManager.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if chatManager.isBotTyping && !chatManager.isStreaming {
                        TypingBubble()
                            .id("typing-bubble")
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await chatManager.loadMoreHistory()
            }
            .onTapGesture {
                // Re-focus instead of dismissing keyboard to keep conversation flow
                isTextFieldFocused.wrappedValue = true
            }
            .onChange(of: chatManager.messages.count) {
                // Auto-scroll to latest message
                if let lastMessage = chatManager.messages.last, !chatManager.isLoadingHistory {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatManager.isBotTyping) {
                // Auto-scroll to typing bubble when bot starts typing
                if chatManager.isBotTyping {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("typing-bubble", anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatManager.isStreaming) {
                // Keep scrolled to bottom during streaming
                if chatManager.isStreaming, let lastMessage = chatManager.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct HistoryLoader: View {
    @ObservedObject var chatManager: ChatManager

    var body: some View {
        HStack {
            Spacer()
            if chatManager.isLoadingHistory {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Load More") {
                    Task { await chatManager.loadMoreHistory() }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

private struct InputArea: View {
    @Binding var messageText: String
    var isTextFieldFocused: FocusState<Bool>.Binding
    @ObservedObject var chatManager: ChatManager
    let sendMessage: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                TextField("Type your message", text: $messageText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                    .focused(isTextFieldFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .submitLabel(.send)
                    // Keep focus when streaming starts
                    .onChange(of: chatManager.isStreaming) {
                        if chatManager.isStreaming {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused.wrappedValue = true
                            }
                        }
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty || chatManager.isLoading)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}
