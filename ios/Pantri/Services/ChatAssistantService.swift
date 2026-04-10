import Foundation
import SwiftData

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    var actions: [ChatAction]

    enum Role: String {
        case user
        case assistant
        case system
    }

    enum ChatAction: Equatable {
        case goToHome
        case goToShoppingList
    }

    init(role: Role, content: String, timestamp: Date = .now, actions: [ChatAction] = []) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.actions = actions
    }
}

// MARK: - Chat Response

struct ChatResponse {
    let text: String
    let actions: [ChatMessage.ChatAction]
}

// MARK: - Parsed Grocery Item

struct ParsedGroceryItem {
    let name: String
    let qty: Double?
    let unit: String?
}

// MARK: - Protocol

protocol ChatAssistantServiceProtocol {
    var conversationHistory: [ChatMessage] { get }
    func sendMessage(_ text: String, context: ModelContext) async throws -> ChatResponse
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
        EnvLoader.value(for: "OPENROUTER_API_KEY") ?? ""
    }

    init(homeScreenService: HomeScreenServiceProtocol = HomeScreenService()) {
        self.homeScreenService = homeScreenService
    }

    func sendMessage(_ text: String, context: ModelContext) async throws -> ChatResponse {
        // Build system prompt with current inventory
        var systemPrompt = (try? buildSystemPrompt(context: context)) ?? defaultSystemPrompt
        var detectedActions: [ChatMessage.ChatAction] = []

        // Detect purchase intent & execute on SwiftData immediately
        let lower = text.lowercased()
        let isPurchase = lower.contains("bought") || lower.contains("purchased")
            || lower.contains("picked up") || lower.contains("restocked")
            || lower.contains("got") || lower.contains("just got")
            
        let isAdd = lower.contains("add ") || lower.contains("need ") || lower.contains("we are out of") 
            || lower.contains("put ") || lower.contains("track ")

        let isListQuery = lower.contains("shopping list") || lower.contains("make a list")
            || lower.contains("what do i need") || lower.contains("what should i buy")
            || lower.contains("i need to buy") || lower.contains("what to buy")
            || lower.contains("grocery list") || lower.contains("list of")
            || lower.contains("running low")

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
                    detectedActions.append(.goToHome)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .pantriInventoryChanged, object: nil)
                    }
                }
            }
        } else if isAdd {
            let parsedItems = await parseGroceryItems(from: text)
            var addedNames: [String] = []
            let itemRepo = SwiftDataItemRepository()

            for item in parsedItems {
                let nameLower = item.name.lowercased()
                if let allItems = try? itemRepo.fetchActive(context: context) {
                    let exists = allItems.contains {
                        $0.canonicalName == nameLower || $0.name.lowercased() == nameLower
                    }
                    if !exists {
                        let newItem = TrackedItem(name: item.name.capitalized, category: .other)
                        context.insert(newItem)
                        let profile = ConsumptionProfile(
                            baselineDays: 14,
                            currentEstimatedDays: 14,
                            confidenceScore: 0.2,
                            isPerishable: false,
                            reminderLeadDays: 3
                        )
                        context.insert(profile)
                        newItem.consumptionProfile = profile
                        addedNames.append(item.name.capitalized)
                    }
                }
            }

            if !addedNames.isEmpty {
                let joined = addedNames.joined(separator: ", ")
                systemPrompt += "\n\n[SYSTEM: The following items have been added to the user's pantry: \(joined). Acknowledge cheerfully.]"
                detectedActions.append(.goToHome)
                try? context.save()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .pantriInventoryChanged, object: nil)
                }
            }
        }

        // Detect list/dashboard query intent and suggest navigation
        if isListQuery {
            detectedActions.append(.goToShoppingList)
            detectedActions.append(.goToHome)
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

            let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip any tool-code artifacts the model might emit
            let reply = Self.stripToolCodes(raw)
            conversationHistory.append(ChatMessage(role: .assistant, content: reply))
            return ChatResponse(text: reply, actions: detectedActions)
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

    // MARK: - LLM-based grocery item parser

    private static let parseSystemPrompt = """
    You are a grocery item extractor. Extract ONLY grocery/household items from voice input.

    RULES:
    1. IGNORE action phrases: "make a list", "add to my cart", "I need", "we need", "please", "help me"
    2. KEEP multi-word items together: "paper towels" → one item, "peanut butter" → one item
    3. SPLIT items separated by commas or "and"
    4. For quantities: "2 gallons of milk" → {name:"milk", qty:2, unit:"gallon"}
    5. IGNORE negations: "we have eggs but need milk" → extract only "milk"
    6. If no grocery items are present, return empty array

    Return ONLY valid JSON — no markdown, no explanation:
    {"items": [{"name": string, "qty": number|null, "unit": string|null}]}

    EXAMPLES:
    "I need steak salmon chicken diapers make a list" → {"items":[{"name":"steak","qty":null,"unit":null},{"name":"salmon","qty":null,"unit":null},{"name":"chicken","qty":null,"unit":null},{"name":"diapers","qty":null,"unit":null}]}
    "apples, bananas and milk" → {"items":[{"name":"apples","qty":null,"unit":null},{"name":"bananas","qty":null,"unit":null},{"name":"milk","qty":null,"unit":null}]}
    "2 gallons of milk and paper towels" → {"items":[{"name":"milk","qty":2,"unit":"gallon"},{"name":"paper towels","qty":null,"unit":null}]}
    "we have eggs but need bread" → {"items":[{"name":"bread","qty":null,"unit":null}]}
    "make a shopping list" → {"items":[]}
    """

    private func parseGroceryItems(from text: String) async -> [ParsedGroceryItem] {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.parseSystemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 500,
            "temperature": 0,
            "response_format": ["type": "json_object"]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return [] }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
        request.setValue("https://pantri.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Pantri", forHTTPHeaderField: "X-OpenRouter-Title")
        request.httpBody = bodyData
        request.timeoutInterval = 30

        guard
            let (data, _) = try? await URLSession.shared.data(for: request),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let content = choices.first?["message"] as? [String: Any],
            let raw = content["content"] as? String,
            let itemData = raw.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: itemData) as? [String: Any],
            let items = parsed["items"] as? [[String: Any]]
        else {
            print("[ChatAssistantService] parseGroceryItems: failed to parse LLM response")
            return []
        }

        return items.compactMap { item in
            guard let name = item["name"] as? String, !name.isEmpty else { return nil }
            return ParsedGroceryItem(
                name: name,
                qty: item["qty"] as? Double,
                unit: item["unit"] as? String
            )
        }
    }

    // MARK: - System prompt

    private func buildSystemPrompt(context: ModelContext) throws -> String {
        let data = try homeScreenService.deriveHomeScreen(context: context)

        var lines = [
            "You are Pantri, a warm and friendly household pantry assistant.",
            "Help users track and manage their household items.",
            "Be concise (2-3 sentences max unless asked for a list), practical, and friendly.",
            "Use soft language: 'likely', 'probably', 'might need soon'.",
            "IMPORTANT: Always respond in natural, conversational language.",
            "NEVER output tool codes, function calls, or structured commands like ADD_ITEM, REMOVE_ITEM, etc.",
            "When items are added or purchased, confirm naturally e.g. 'Milk has been added to your pantry!'",
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
        Always respond in natural, conversational language. Never output tool codes or structured commands.
        The user hasn't added any items yet \u{2014} encourage them to tap + to add their first items.
        """
    }

    // MARK: - Helpers

    private static func stripToolCodes(_ text: String) -> String {
        // Remove lines like `tool_code ADD_ITEM:Milk` or ```tool_code ... ```
        var result = text
        // Remove fenced tool_code blocks
        result = result.replacingOccurrences(
            of: "```tool_code[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )
        // Remove inline tool_code lines
        result = result.replacingOccurrences(
            of: "(?m)^\\s*tool_code\\s+.*$",
            with: "",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
