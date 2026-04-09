import SwiftUI
import SwiftData

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading = false
    var errorMessage: String?
    var isVoiceMode: Bool = false
    var voiceTranscript: String = ""

    private let chatService: ChatAssistantServiceProtocol

    init(chatService: ChatAssistantServiceProtocol = ChatAssistantService()) {
        self.chatService = chatService
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Send (text input)

    @MainActor
    func sendMessage(context: ModelContext) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        await send(text: text, context: context)
    }

    // MARK: - Send (voice)

    @MainActor
    func sendVoiceMessage(_ text: String, context: ModelContext) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        voiceTranscript = ""
        await send(text: trimmed, context: context)
    }

    // MARK: - Core send

    @MainActor
    private func send(text: String, context: ModelContext) async {
        isLoading = true
        errorMessage = nil

        // Show user bubble immediately for snappy feel
        messages.append(ChatMessage(role: .user, content: text))

        do {
            let reply = try await chatService.sendMessage(text, context: context)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            // Show error inline as an assistant message + store for banner
            let errMsg = error.localizedDescription
            errorMessage = errMsg
            messages.append(ChatMessage(
                role: .assistant,
                content: "Something went wrong: \(errMsg)\n\nPlease check your connection and try again."
            ))
        }

        isLoading = false
    }

    // MARK: - Voice mode

    func toggleVoiceMode() {
        isVoiceMode.toggle()
        if !isVoiceMode { voiceTranscript = "" }
    }

    // MARK: - Clear

    func clearChat() {
        messages.removeAll()
        chatService.clearConversation()
        errorMessage = nil
        voiceTranscript = ""
    }
}
