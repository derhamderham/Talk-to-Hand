//
//  SettingsView.swift
//  Talk to Hand
//
//  Created by derham on 7/12/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var chatManager: ChatManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Server URL", text: $chatManager.serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: $chatManager.apiKey)
                        .autocorrectionDisabled()
                    TextField("Model Name", text: $chatManager.modelName)
                        .autocorrectionDisabled()
                }
                
                Section("Actions") {
                    Button("Clear Chat History") {
                        chatManager.clearMessages()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedModel = settingsManager.modelName
            }
        }
    }
}
