import Foundation
import SwiftData

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String, timestamp: Date = .now) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Protocol

protocol ChatAssistantServiceProtocol {
    var conversationHistory: [ChatMessage] { get }
    func sendMessage(_ text: String, context: ModelContext) async throws -> String
    func clearConversation()
}

// MARK: - Implementation

/// Lightweight chat assistant backed by OpenRouter API (Gemma model).
/// Builds local context from item predictions to answer questions about the household pantry.
/// API key must be stored securely (Keychain) — never hardcoded.
final class ChatAssistantService: ChatAssistantServiceProtocol {
    private(set) var conversationHistory: [ChatMessage] = []
    private let homeScreenService: HomeScreenServiceProtocol
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "google/gemma-3-27b-it:free"

    init(homeScreenService: HomeScreenServiceProtocol = HomeScreenService()) {
        self.homeScreenService = homeScreenService
    }

    func sendMessage(_ text: String, context: ModelContext) async throws -> String {
        // Build system prompt with local context
        let systemPrompt = try buildSystemPrompt(context: context)

        // Add user message to history
        conversationHistory.append(ChatMessage(role: .user, content: text))

        // Build API request
        let apiKey = try loadAPIKey()
        let requestBody = buildRequestBody(systemPrompt: systemPrompt)

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ChatError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let reply = message?["content"] as? String ?? "I couldn't generate a response."

        conversationHistory.append(ChatMessage(role: .assistant, content: reply))
        return reply
    }

    func clearConversation() {
        conversationHistory.removeAll()
    }

    // MARK: - Private

    private func buildSystemPrompt(context: ModelContext) throws -> String {
        let data = try homeScreenService.deriveHomeScreen(context: context)

        var lines = [
            "You are a helpful household assistant for an app called Pantri.",
            "You help users track when they need to buy household items.",
            "Be brief, friendly, and practical. Never claim to know exact stock levels.",
            "Use soft language like 'likely', 'probably', 'might need soon'.",
            "",
            "Current pantry status:"
        ]

        if !data.needSoon.isEmpty {
            lines.append("Items likely needed soon:")
            for item in data.needSoon {
                lines.append("- \(item.name): \(item.explanation)")
            }
        }

        if !data.thisWeek.isEmpty {
            lines.append("Items to watch this week:")
            for item in data.thisWeek {
                lines.append("- \(item.name): \(item.subtitle)")
            }
        }

        lines.append("Total tracked items: \(data.totalTrackedItems)")
        lines.append("Items in good standing: \(data.youreGood.count)")

        return lines.joined(separator: "\n")
    }

    private func buildRequestBody(systemPrompt: String) -> [String: Any] {
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for msg in conversationHistory {
            messages.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }

        return [
            "model": model,
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.7
        ]
    }

    /// Loads API key from Keychain. For MVP, falls back to UserDefaults (user sets in settings).
    private func loadAPIKey() throws -> String {
        // Try Keychain first
        if let key = KeychainHelper.read(key: "openrouter_api_key"), !key.isEmpty {
            return key
        }

        // Fallback to UserDefaults (less secure, but acceptable for MVP setup flow)
        if let key = UserDefaults.standard.string(forKey: "openrouter_api_key"), !key.isEmpty {
            return key
        }

        throw ChatError.noAPIKey
    }

    enum ChatError: Error, LocalizedError {
        case apiError
        case noAPIKey
        case offline

        var errorDescription: String? {
            switch self {
            case .apiError: return "Could not get a response from the assistant"
            case .noAPIKey: return "No API key configured. Set your OpenRouter key in Settings."
            case .offline: return "Chat is unavailable offline"
            }
        }
    }
}

// MARK: - Keychain Helper

/// Minimal Keychain wrapper for storing the API key securely.
enum KeychainHelper {
    private static let service = "com.pantri.app"

    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary) // Remove existing
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
