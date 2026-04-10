import SwiftUI
import SwiftData

// MARK: - Chat Session (persisted to UserDefaults)

struct ChatSession: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
    var messages: [SavedMessage]

    struct SavedMessage: Codable {
        let role: String      // "user" or "assistant"
        let content: String
        let timestamp: Date
    }
}

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading = false
    var errorMessage: String?
    var isVoiceMode: Bool = false
    var voiceTranscript: String = ""
    var savedSessions: [ChatSession] = []

    private let chatService: ChatAssistantServiceProtocol
    private let sessionsKey = "pantri_chat_sessions"
    private var currentSessionId: UUID? = nil

    init(chatService: ChatAssistantServiceProtocol = ChatAssistantService()) {
        self.chatService = chatService
        loadSessions()
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
            let response = try await chatService.sendMessage(text, context: context)
            messages.append(ChatMessage(role: .assistant, content: response.text, actions: response.actions))
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
        currentSessionId = nil
    }

    // MARK: - New chat (saves current first)

    func startNewChat() {
        saveCurrentSession()
        clearChat()
    }

    // MARK: - Session Persistence

    func saveCurrentSession() {
        guard !messages.isEmpty else { return }

        let savedMsgs = messages.map { msg in
            ChatSession.SavedMessage(
                role: msg.role.rawValue,
                content: msg.content,
                timestamp: msg.timestamp
            )
        }

        let title = messages.first(where: { $0.role == .user })?.content
            .prefix(40)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "Chat"

        if let existingIndex = savedSessions.firstIndex(where: { $0.id == currentSessionId }) {
            savedSessions[existingIndex].messages = savedMsgs
        } else {
            let session = ChatSession(
                id: currentSessionId ?? UUID(),
                title: String(title),
                date: messages.first?.timestamp ?? .now,
                messages: savedMsgs
            )
            currentSessionId = session.id
            savedSessions.insert(session, at: 0)
        }

        persistSessions()
    }

    func loadSession(_ session: ChatSession) {
        saveCurrentSession()
        messages = session.messages.map { saved in
            ChatMessage(
                role: ChatMessage.Role(rawValue: saved.role) ?? .user,
                content: saved.content,
                timestamp: saved.timestamp
            )
        }
        currentSessionId = session.id
        chatService.clearConversation()
    }

    func deleteSession(_ session: ChatSession) {
        savedSessions.removeAll { $0.id == session.id }
        if currentSessionId == session.id {
            currentSessionId = nil
        }
        persistSessions()
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data)
        else { return }
        savedSessions = sessions
    }

    private func persistSessions() {
        // Keep max 50 sessions
        if savedSessions.count > 50 {
            savedSessions = Array(savedSessions.prefix(50))
        }
        if let data = try? JSONEncoder().encode(savedSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
}
