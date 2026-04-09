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

final class ChatAssistantService: ChatAssistantServiceProtocol {
    private(set) var conversationHistory: [ChatMessage] = []
    private let homeScreenService: HomeScreenServiceProtocol
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    
    // Dynamically load from .env if available, otherwise use hardcoded defaults
    // Note: openai/gpt-audio-mini can throw 400 if sent text-only on some providers.
    // Falling back to gpt-4o-mini for maximum reliability.
    private var model: String {
        EnvLoader.value(for: "OPENROUTER_MODEL") ?? "openai/gpt-4o-mini"
    }
    
    private var apiKey: String {
        EnvLoader.value(for: "OPENROUTER_API_KEY") ?? "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"
    }

    init(homeScreenService: HomeScreenServiceProtocol = HomeScreenService()) {
        self.homeScreenService = homeScreenService
    }

    func sendMessage(_ text: String, context: ModelContext) async throws -> String {
        // Build system prompt with current inventory
        var systemPrompt = (try? buildSystemPrompt(context: context)) ?? defaultSystemPrompt

        // Detect purchase intent & execute on SwiftData immediately
        let lower = text.lowercased()
        let isPurchase = lower.contains("bought") || lower.contains("purchased")
            || lower.contains("picked up") || lower.contains("restocked")
            || lower.contains("got") || lower.contains("just got")
            
        let isAdd = lower.contains("add ") || lower.contains("need ") || lower.contains("we are out of") 
            || lower.contains("put ") || lower.contains("track ")

        if isPurchase {
            let itemRepo = SwiftDataItemRepository()
            let purchaseRepo = SwiftDataPurchaseRepository()

            if let allItems = try? itemRepo.fetchActive(context: context) {
                let matched = allItems.filter { item in
                    lower.contains(item.canonicalName) || lower.contains(item.name.lowercased())
                }
                if !matched.isEmpty {
                    for item in matched {
                        let event = PurchaseEvent(source: .manual)
                        try? purchaseRepo.recordPurchase(event, for: item, context: context)
                    }
                    let names = matched.map(\.name).joined(separator: ", ")
                    systemPrompt += "\n\n[SYSTEM: Purchase recorded for: \(names). Inventory updated. Acknowledge cheerfully.]"
                }
            }
        } else if isAdd {
            // Very simple hardcoded extraction for common items
            let commonItems = ["milk", "eggs", "bread", "cheese", "butter", "apples", "bananas", "chicken", "beef", "rice", "pasta", "coffee", "water", "juice", "cereal"]
            var addedNames: [String] = []
            
            for word in commonItems {
                if lower.contains(word) {
                    // Check if it exists
                    let itemRepo = SwiftDataItemRepository()
                    if let allItems = try? itemRepo.fetchActive(context: context) {
                        let exists = allItems.contains { $0.canonicalName == word || $0.name.lowercased() == word }
                        if !exists {
                            let newItem = TrackedItem(name: word.capitalized)
                            context.insert(newItem)
                            // Create a profile with a 0-day interval so it triggers 'buyNow' immediately
                            let profile = ConsumptionProfile(
                                baselineDays: 0,
                                currentEstimatedDays: 0,
                                confidenceScore: 0.1,
                                reminderLeadDays: 7
                            )
                            context.insert(profile)
                            newItem.consumptionProfile = profile
                            addedNames.append(word.capitalized)
                        }
                    }
                }
            }
            if !addedNames.isEmpty {
                let joined = addedNames.joined(separator: ", ")
                systemPrompt += "\n\n[SYSTEM: The following items have been actively added to the user's pantry system: \(joined). Acknowledge that you have added them.]"
                try? context.save()
            }
        }

        // Append user message to history
        conversationHistory.append(ChatMessage(role: .user, content: text))

        // Build messages array for API
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        // Include last 10 turns for context (keeps tokens low)
        let historySlice = conversationHistory.suffix(10)
        for msg in historySlice {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Build request
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 300,
            "temperature": 0.7
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw ChatError.encodingError
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
        request.setValue("https://pantri.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Pantri", forHTTPHeaderField: "X-OpenRouter-Title")
        request.httpBody = bodyData
        request.timeoutInterval = 45 

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                print("[ChatAssistantService] Critical Error: Not an HTTP response")
                throw ChatError.invalidResponse
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("[ChatAssistantService] API Error Status \(http.statusCode): \(body)")
                throw ChatError.httpError(http.statusCode)
            }

            // Parse response
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else {
                let raw = String(data: data, encoding: .utf8) ?? "empty"
                print("[ChatAssistantService] Parsing Error. Raw response: \(raw)")
                throw ChatError.invalidResponse
            }

            let reply = content.trimmingCharacters(in: .whitespacesAndNewlines)
            conversationHistory.append(ChatMessage(role: .assistant, content: reply))
            return reply
        } catch let error as URLError {
            print("[ChatAssistantService] Network Error: \(error.localizedDescription) (code: \(error.code.rawValue))")
            throw error
        } catch {
            print("[ChatAssistantService] Unknown Error: \(error.localizedDescription)")
            throw error
        }
    }

    func clearConversation() {
        conversationHistory.removeAll()
    }

    // MARK: - System prompt

    private func buildSystemPrompt(context: ModelContext) throws -> String {
        let data = try homeScreenService.deriveHomeScreen(context: context)

        var lines = [
            "You are Pantri, a warm and friendly household pantry assistant.",
            "Help users track and manage their household items.",
            "Be concise (2-3 sentences max unless asked for a list), practical, and friendly.",
            "Use soft language: 'likely', 'probably', 'might need soon'.",
            "",
            "CURRENT PANTRY STATUS:"
        ]

        if !data.needSoon.isEmpty {
            lines.append("Items likely needed soon:")
            for item in data.needSoon {
                lines.append("  - \(item.name): \(item.explanation)")
            }
        }

        if !data.thisWeek.isEmpty {
            lines.append("Items to watch this week:")
            for item in data.thisWeek {
                lines.append("  - \(item.name): \(item.subtitle)")
            }
        }

        lines.append("Well-stocked items: \(data.youreGood.count)")
        lines.append("Total tracked: \(data.totalTrackedItems)")

        return lines.joined(separator: "\n")
    }

    private var defaultSystemPrompt: String {
        """
        You are Pantri, a warm and friendly household pantry assistant.
        Help users track and manage their household items.
        Be concise (2-3 sentences), practical, and friendly.
        The user hasn't added any items yet \u{2014} encourage them to tap + to add their first items.
        """
    }

    // MARK: - Errors

    enum ChatError: Error, LocalizedError {
        case encodingError
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .encodingError: return "Could not prepare the message"
            case .invalidResponse: return "Unexpected response from the assistant"
            case .httpError(let code):
                switch code {
                case 400: return "Bad request (400) — the model may not support this input format"
                case 401: return "Unauthorized (401) — check your API key"
                case 402: return "Payment required (402) — check your OpenRouter credits"
                case 429: return "Rate limited (429) — try again in a moment"
                case 503: return "Service unavailable (503) — the model is temporarily down"
                default: return "Server error (\(code))"
                }
            }
        }
    }
}

// MARK: - Keychain Helper

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
        SecItemDelete(query as CFDictionary)
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
