import SwiftUI
import Foundation

/// Generates and caches small food/item icons via OpenRouter image generation.
actor ItemImageService {
    static let shared = ItemImageService()

    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    private var cache: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private var apiKey: String {
        EnvLoader.value(for: "OPENROUTER_API_KEY") ?? ""
    }
    private var model: String {
        EnvLoader.value(for: "OPENROUTER_IMAGE_MODEL") ?? "google/gemini-2.5-flash-preview:thinking"
    }

    /// Returns a cached image or generates one. Thread-safe.
    func image(for itemName: String, category: String) async -> UIImage? {
        let key = itemName.lowercased()

        if let cached = cache[key] { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> {
            let img = await generate(itemName: itemName, category: category)
            if let img { cache[key] = img }
            return img
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    private func generate(itemName: String, category: String) async -> UIImage? {
        let prompt = "Generate a single small, clean, minimal flat-style icon of \(itemName) (\(category) category). White background, centered, no text, no shadow, suitable as an app icon at 120x120px. Cute and friendly style."

        let messages: [[String: Any]] = [
            ["role": "user", "content": [
                ["type": "text", "text": prompt]
            ]]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 4096
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
        request.setValue("Pantri", forHTTPHeaderField: "X-OpenRouter-Title")
        request.httpBody = bodyData
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }

            // Try to extract base64 image data from the response
            if let imageData = extractBase64Image(from: content) {
                return UIImage(data: imageData)
            }
            return nil
        } catch {
            return nil
        }
    }

    private func extractBase64Image(from text: String) -> Data? {
        // Look for base64 data in markdown image or raw base64
        let patterns = [
            "data:image/[^;]+;base64,([A-Za-z0-9+/=\\n\\r]+)",
            "\\[?!?\\[?[^]]*\\]?\\(?data:image/[^;]+;base64,([A-Za-z0-9+/=\\n\\r]+)\\)?",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let base64 = String(text[range]).replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                return Data(base64Encoded: base64)
            }
        }
        // Try treating entire content as base64
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 100, let data = Data(base64Encoded: cleaned), data.count > 100 {
            return data
        }
        return nil
    }
}

/// SwiftUI view that shows an AI-generated image or falls back to emoji
struct ItemImageView: View {
    let itemName: String
    let category: ItemCategory
    let size: CGFloat

    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                // Fallback: emoji on tinted background
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .fill(category == .other ? Color.pantriSurface : Color.pantriGreenLight)
                    Text(category.emoji)
                        .font(.system(size: size * 0.5))
                }
                .frame(width: size, height: size)
            }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            image = await ItemImageService.shared.image(for: itemName, category: category.displayName)
        }
    }
}
