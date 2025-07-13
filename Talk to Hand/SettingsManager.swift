//
//  SettingsManager.swift
//  Talk to Hand
//
//  Created by derham on 7/15/25.
//

import Foundation
import Security

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Persisted model name
    var modelName: String {
        get { UserDefaults.standard.string(forKey: UserDefaultsKeys.modelName) ?? "Menlo:Jan-nano-128k-gguf:jan-nano-128k-Q8_0.gguf" }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.modelName) }
    }

    // Models discovered from /v1/models
    @Published var availableModels: [String] = []

    // Fetch models from the API server
    @MainActor
    func fetchAvailableModels(serverURL: String, apiKey: String) async {
        guard let url = URL(string: "\(serverURL)/v1/models") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            struct Response: Decodable {
                let data: [ModelEntry]
                struct ModelEntry: Decodable { let id: String }
            }
            let models = try JSONDecoder().decode(Response.self, from: data).data.map { $0.id }
            self.availableModels = models
        } catch {
            print("Failed to fetch models: \(error)")
        }
    }

    // MARK: - UserDefaults Keys
    private enum UserDefaultsKeys {
        static let serverURL = "serverURL"
        static let modelName = "modelName"
    }
    
    // MARK: - Keychain Keys
    private enum KeychainKeys {
        static let apiKey = "apiKey"
    }
    
    // MARK: - Server URL (stored in UserDefaults)
    var serverURL: String {
        get { UserDefaults.standard.string(forKey: UserDefaultsKeys.serverURL) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.serverURL) }
    }

    // MARK: - API Key (stored in Keychain)
    var apiKey: String {
        get { getFromKeychain(key: KeychainKeys.apiKey) ?? "" }
        set { saveToKeychain(key: KeychainKeys.apiKey, value: newValue) }
    }
    
    // MARK: - Keychain Helpers
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
}
