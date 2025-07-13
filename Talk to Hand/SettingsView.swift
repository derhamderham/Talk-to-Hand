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
                    modelPickerView
                } header: {
                    Text("Server Configuration")
                }

                Section("Actions") {
                    Button("Clear Chat History") { chatManager.clearMessages() }
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                selectedModel = settingsManager.modelName
            }
        }
    }
    @ViewBuilder
    private var modelPickerView: some View {
        if !settingsManager.availableModels.isEmpty {
            Picker("Model Name", selection: $selectedModel) {
                ForEach(settingsManager.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .onChange(of: selectedModel) {
                settingsManager.modelName = selectedModel
                chatManager.modelName = selectedModel
            }
        } else {
            Button("Fetch Model List") {
                Task {
                    await settingsManager.fetchAvailableModels(
                        serverURL: chatManager.serverURL,
                        apiKey: chatManager.apiKey
                    )
                }
            }
        }
    }
}
