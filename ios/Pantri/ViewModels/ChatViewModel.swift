import SwiftUI
import SwiftData

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading = false
    var errorMessage: String?

    private let chatService: ChatAssistantServiceProtocol

    init(chatService: ChatAssistantServiceProtocol = ChatAssistantService()) {
        self.chatService = chatService
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    @MainActor
    func sendMessage(context: ModelContext) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        isLoading = true
        errorMessage = nil

        // Add user message immediately for responsiveness
        messages.append(ChatMessage(role: .user, content: text))

        do {
            let reply = try await chatService.sendMessage(text, context: context)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            errorMessage = error.localizedDescription
            // Add error message to chat for visibility
            messages.append(ChatMessage(
                role: .assistant,
                content: "Sorry, I couldn't respond right now. \(error.localizedDescription)"
            ))
        }

        isLoading = false
    }

    func clearChat() {
        messages.removeAll()
        chatService.clearConversation()
        errorMessage = nil
    }
}
