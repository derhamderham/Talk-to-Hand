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
    
    // MARK: - Published Properties
    @Published var availableModels: [String] = []
    @Published var isFetching: Bool = false
    
    
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
    
    // MARK: - Model Name (stored in UserDefaults)
    var modelName: String {
        get { UserDefaults.standard.string(forKey: UserDefaultsKeys.modelName) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.modelName) }
    }
    
    // MARK: - API Key (stored in Keychain)
    var apiKey: String {
        get { getFromKeychain(key: KeychainKeys.apiKey) ?? "" }
        set { saveToKeychain(key: KeychainKeys.apiKey, value: newValue) }
    }
    
    // MARK: - Fetch Models
    @MainActor
    func fetchAvailableModels() async {
        let currentServerURL = serverURL
        let currentApiKey = apiKey
        
        guard !currentServerURL.isEmpty,
              currentServerURL.hasPrefix("http://") || currentServerURL.hasPrefix("https://"),
              let url = URL(string: "\(currentServerURL)/v1/models") else {
            print("Invalid server URL: '\(currentServerURL)'")
            self.availableModels = []
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(currentApiKey)", forHTTPHeaderField: "Authorization") // FIXED
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("Fetching models from: \(url)")
        print("Using API key: \(currentApiKey.isEmpty ? "EMPTY" : "***")")
        
        self.isFetching = true
        defer { self.isFetching = false }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                return
            }
            
            print("HTTP Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("HTTP Error: \(httpResponse.statusCode)")
                self.availableModels = []
                return
            }
            
            // Try to decode the response
            struct Response: Decodable {
                let data: [ModelEntry]
                struct ModelEntry: Decodable {
                    let id: String
                }
            }
            
            let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
            let models = decodedResponse.data.map { $0.id }
            
            print("Successfully decoded \(models.count) models: \(models)")
            self.availableModels = models
            
        } catch {
            print("Failed to fetch models: \(error)")
            if let decodingError = error as? DecodingError {
                print("Decoding error details: \(decodingError)")
            }
            self.availableModels = []
        }
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
