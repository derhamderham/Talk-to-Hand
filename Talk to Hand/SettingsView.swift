//
//  SettingsView.swift
//  Talk to Hand
//
//  Created by derham on 7/12/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var chatManager: ChatManager          // still needed for clear history, etc.
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var serverURLTemp : String = ""
    @State private var apiKeyTemp    : String = ""
    
    var body: some View {
        NavigationView {
            Form {
                
                // MARK: – Server / API key inputs (kept as plain text)
                Section(header: Text("Connection")) {
                    TextField("Server URL", text: $serverURLTemp)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: $apiKeyTemp)
                        .autocorrectionDisabled()
                    
                    // Save button to propagate changes *and* trigger fetch
                    Button("Save & Refresh Models") {
                        settings.serverURL = serverURLTemp
                        settings.apiKey    = apiKeyTemp
                        Task { await loadModels() }
                    }
                }
                
                // MARK: – Model picker
                Section(header: Text("Model")) {
                    if settings.isFetching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if settings.availableModels.isEmpty {
                        Text("No models available")
                            .foregroundColor(.secondary)
                    } else {
                        // Use NavigationLink style instead of MenuPickerStyle
                        Picker("Select Model", selection: $settings.modelName) {
                            ForEach(settings.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(NavigationLinkPickerStyle()) // Changed this line
                        
                        // Show currently selected model clearly
                        HStack {
                            Text("Selected:")
                            Spacer()
                            Text(settings.modelName.isEmpty ? "None" : settings.modelName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: – Other actions
                Section(header: Text("History")) {
                    Button(role: .destructive) {
                        chatManager.clearMessages()
                    } label: {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Populate the temp fields on first appearance
            .onAppear {
                serverURLTemp = settings.serverURL
                apiKeyTemp    = settings.apiKey
                Task { await loadModels() }      // initial fetch
            }
        }
    }
    

    // MARK: – Helper to call the async fetch
    
    @MainActor
    private func loadModels() async {
        await settings.fetchAvailableModels()  // No parameters needed
    }
}
