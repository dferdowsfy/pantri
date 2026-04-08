import Foundation

// MARK: - OCR Provider Protocol

/// Protocol for receipt image extraction. Implementations can use Vision, OpenAI, Gemini, or any custom API.
protocol OCRProviderProtocol {
    func extractItems(from imageData: Data) async throws -> [ExtractedReceiptItemDTO]
}

// MARK: - Stub OCR Provider (for testing and development)

/// Returns mock extracted items. Used during development and in unit tests.
struct StubOCRProvider: OCRProviderProtocol {
    func extractItems(from imageData: Data) async throws -> [ExtractedReceiptItemDTO] {
        // Simulate a short processing delay
        try await Task.sleep(for: .milliseconds(500))

        return [
            ExtractedReceiptItemDTO(rawText: "WHOLE MILK 1 GAL", normalizedName: "milk", confidence: 0.9),
            ExtractedReceiptItemDTO(rawText: "EGGS LARGE DOZ", normalizedName: "eggs", confidence: 0.85),
            ExtractedReceiptItemDTO(rawText: "BREAD WHEAT", normalizedName: "bread", confidence: 0.8),
            ExtractedReceiptItemDTO(rawText: "BANANAS ORGANIC", normalizedName: "bananas", confidence: 0.85),
            ExtractedReceiptItemDTO(rawText: "GREEK YOGURT", normalizedName: "yogurt", confidence: 0.75),
        ]
    }
}

// MARK: - OpenRouter OCR Provider (skeleton)

/// Sends receipt images to OpenRouter API with a vision-capable model for text extraction.
/// This is a skeleton implementation — requires a vision model endpoint.
struct OpenRouterOCRProvider: OCRProviderProtocol {
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "google/gemma-3-27b-it:free"

    func extractItems(from imageData: Data) async throws -> [ExtractedReceiptItemDTO] {
        let apiKey = try loadAPIKey()

        let base64Image = imageData.base64EncodedString()

        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You are a receipt parser. Extract grocery item names from the receipt image. Return a JSON array of objects with 'rawText' (original text from receipt) and 'normalizedName' (common item name, lowercase). Only include food and household items."
            ],
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": "Extract the grocery items from this receipt:"],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 1000,
            "temperature": 0.1
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OCRError.extractionFailed
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> [ExtractedReceiptItemDTO] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OCRError.parseError
        }

        // Try to extract JSON array from the response
        guard let jsonData = content.data(using: .utf8) else {
            throw OCRError.parseError
        }

        struct ParsedItem: Codable {
            let rawText: String
            let normalizedName: String
        }

        do {
            let items = try JSONDecoder().decode([ParsedItem].self, from: jsonData)
            return items.map { ExtractedReceiptItemDTO(rawText: $0.rawText, normalizedName: $0.normalizedName, confidence: 0.7) }
        } catch {
            // If direct JSON parsing fails, try to find JSON in the response
            if let start = content.firstIndex(of: "["),
               let end = content.lastIndex(of: "]") {
                let jsonString = String(content[start...end])
                if let jsonData = jsonString.data(using: .utf8) {
                    let items = try JSONDecoder().decode([ParsedItem].self, from: jsonData)
                    return items.map { ExtractedReceiptItemDTO(rawText: $0.rawText, normalizedName: $0.normalizedName, confidence: 0.7) }
                }
            }
            throw OCRError.parseError
        }
    }

    private func loadAPIKey() throws -> String {
        if let key = KeychainHelper.read(key: "openrouter_api_key"), !key.isEmpty {
            return key
        }
        if let key = UserDefaults.standard.string(forKey: "openrouter_api_key"), !key.isEmpty {
            return key
        }
        throw OCRError.noAPIKey
    }

    enum OCRError: Error, LocalizedError {
        case extractionFailed
        case parseError
        case noAPIKey

        var errorDescription: String? {
            switch self {
            case .extractionFailed: return "Receipt extraction failed"
            case .parseError: return "Could not parse extracted items"
            case .noAPIKey: return "No API key configured for OCR"
            }
        }
    }
}
