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
                    Button("Settings") { isShowingSettings = true }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(chatManager: chatManager)
            }
        }
        .onAppear { chatManager.loadInitialMessages() }
    }
        
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let userMessage = messageText
        messageText = ""
        isTextFieldFocused = false
        Task {
            await chatManager.sendMessage(userMessage)
        }
    }
}

private struct MessageList: View {
    @ObservedObject var chatManager: ChatManager
    var isTextFieldFocused: Binding<Bool> // <-- Accept focus as a binding

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
                    if chatManager.isBotTyping {
                        HStack(alignment: .bottom) {
                            TypingBubble()
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await chatManager.loadMoreHistory()
            }
            .onTapGesture {
                isTextFieldFocused.wrappedValue = false // Dismiss keyboard
            }
            .onChange(of: $chatManager.messages.count) {
                if let lastMessage = $chatManager.messages.last, !chatManager.isLoadingHistory {
                    withAnimation(.easeOut(duration: 0.3)) {
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
                    .onSubmit { sendMessage() }
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
