import SwiftUI
import SwiftData
import Combine

// MARK: - Keyboard observer

final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isVisible = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .sink { [weak self] height in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = height
                    self?.isVisible = true
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = 0
                    self?.isVisible = false
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - ChatView

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @State private var speech = SpeechRecognizer()
    @StateObject private var keyboard = KeyboardObserver()
    @State private var showHistory = false

    var body: some View {
        ZStack {
            Color.pantriBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Nav bar ───────────────────────────────────────────
                chatNavBar

                // ── Messages ──────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.messages.isEmpty {
                                emptyState
                            }
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            if viewModel.isLoading {
                                TypingIndicator()
                                    .id("loading")
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .opacity(viewModel.isVoiceMode ? 0.0 : 1.0)
                    .allowsHitTesting(!viewModel.isVoiceMode)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: viewModel.isLoading) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: keyboard.keyboardHeight) { _, _ in
                        scrollToBottom(proxy)
                    }
                }

                // ── Input bar pinned at bottom ───────────────────────
                if !viewModel.isVoiceMode {
                    textInputBar
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Reserve space for floating tab bar when keyboard is hidden
                if !keyboard.isVisible && !viewModel.isVoiceMode {
                    Color.clear.frame(height: 80)
                }
            }

            // ── Centered Voice Mode Overlay ──────────────────────────
            if viewModel.isVoiceMode {
                centeredVoicePanel
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .sheet(isPresented: $showHistory) {
            ChatHistorySheet(
                sessions: viewModel.savedSessions,
                onSelect: { session in
                    viewModel.loadSession(session)
                    showHistory = false
                },
                onDelete: { session in
                    viewModel.deleteSession(session)
                }
            )
        }
        .onChange(of: speech.transcript) { _, newValue in
            viewModel.voiceTranscript = newValue
        }
    }

    // MARK: - Nav bar

    private var chatNavBar: some View {
        HStack {
            // History / hamburger menu
            Button {
                viewModel.saveCurrentSession()
                showHistory = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.pantriText.opacity(0.6))
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text("Pantri Assistant")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.pantriText)

            Spacer()

            // Clear / new chat
            Button {
                viewModel.saveCurrentSession()
                speech.stopListening()
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.pantriText.opacity(0.4))
                    .frame(width: 36, height: 36)
            }
            .disabled(viewModel.messages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Scroll helper

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(duration: 0.3)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Voice helpers

    private func enterVoiceMode() {
        withAnimation(.spring(duration: 0.35)) {
            if !viewModel.isVoiceMode { viewModel.toggleVoiceMode() }
        }
        speech.startListening()
    }

    private func exitVoiceMode(send: Bool) {
        let text = viewModel.voiceTranscript
        speech.stopListening()
        withAnimation(.spring(duration: 0.35)) {
            if viewModel.isVoiceMode { viewModel.toggleVoiceMode() }
        }
        if send && !text.isEmpty {
            Task { await viewModel.sendVoiceMessage(text, context: modelContext) }
        }
    }

    // MARK: - Text input bar

    private var textInputBar: some View {
        HStack(spacing: 10) {
            // Mic button (left)
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                enterVoiceMode()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.pantriGreen)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }

            TextField("Ask about your pantry…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.pantriSurface)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
                )
                .submitLabel(.send)
                .onSubmit {
                    Task { await viewModel.sendMessage(context: modelContext) }
                }

            // Send button (right)
            Button {
                Task { await viewModel.sendMessage(context: modelContext) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(viewModel.canSend ? Color.pantriGreen : Color.pantriGreen.opacity(0.3))
                    .contentShape(Circle())
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.pantriBackground.opacity(0.97)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        )
    }

    // MARK: - Centered Voice Panel

    private var centeredVoicePanel: some View {
        VStack(spacing: 40) {
            Spacer()

            // Globe — visual-only activity indicator
            AnimatedGlobeView(isListening: speech.isListening)
                .frame(width: 200, height: 200)
                .scaleEffect(speech.isListening ? 1.05 : 1.0)
                .animation(.spring(duration: 0.3), value: speech.isListening)

            VStack(spacing: 16) {
                Text(speech.isListening ? "Listening..." : "Starting...")
                    .font(.headline)
                    .foregroundStyle(Color.pantriGreenDark)

                if !viewModel.voiceTranscript.isEmpty {
                    Text(viewModel.voiceTranscript)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.pantriText)
                        .padding(.horizontal, 40)
                        .frame(minHeight: 60)
                } else {
                    Text("How can I help you today?")
                        .font(.body)
                        .foregroundStyle(Color.pantriText.opacity(0.4))
                        .frame(height: 60)
                }
            }

            HStack(spacing: 24) {
                Button { exitVoiceMode(send: false) } label: {
                    Text("Cancel")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.pantriText.opacity(0.5))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }

                Button { exitVoiceMode(send: true) } label: {
                    Text("Send")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(
                            viewModel.voiceTranscript.isEmpty
                                ? Color.pantriGreen.opacity(0.3)
                                : Color.pantriGreen
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .disabled(viewModel.voiceTranscript.isEmpty || viewModel.isLoading)
            }
            .padding(.bottom, 60)

            Spacer()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 48)

            Button {
                enterVoiceMode()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.pantriGreenLight)
                        .frame(width: 80, height: 80)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.pantriGreen)
                }
            }

            VStack(spacing: 6) {
                Text("Ask about your pantry")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.pantriText)

                Text("Tap the mic to speak, or type below.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pantriText.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            VStack(spacing: 8) {
                SuggestionChip("What do I need soon?") {
                    viewModel.inputText = "What do I need soon?"
                    Task { await viewModel.sendMessage(context: modelContext) }
                }
                SuggestionChip("I just bought milk") {
                    viewModel.inputText = "I just bought milk"
                    Task { await viewModel.sendMessage(context: modelContext) }
                }
                SuggestionChip("Make me a shopping list") {
                    viewModel.inputText = "Make me a shopping list"
                    Task { await viewModel.sendMessage(context: modelContext) }
                }
            }
        }
        .padding(.top, 48)
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.pantriGreen)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.pantriText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) } else { botAvatar }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? AnyShapeStyle(Color.pantriGreen)
                            : AnyShapeStyle(Color.pantriSurface)
                    )
                    .foregroundStyle(isUser ? .white : Color.pantriText)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)

                if !isUser && !message.actions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(uniqueActions.indices, id: \.self) { i in
                            chatActionButton(uniqueActions[i])
                        }
                    }
                }
            }

            if !isUser { Spacer(minLength: 50) } else { userAvatar }
        }
    }

    private var uniqueActions: [ChatMessage.ChatAction] {
        var seen = Set<String>()
        return message.actions.filter {
            let key: String
            switch $0 {
            case .goToHome: key = "home"
            case .goToShoppingList: key = "list"
            }
            return seen.insert(key).inserted
        }
    }

    private func chatActionButton(_ action: ChatMessage.ChatAction) -> some View {
        Button {
            switch action {
            case .goToHome:
                NotificationCenter.default.post(
                    name: .pantriSwitchToTab,
                    object: nil,
                    userInfo: ["tab": 0]
                )
            case .goToShoppingList:
                NotificationCenter.default.post(name: .pantriOpenShoppingList, object: nil)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: action == .goToHome ? "house.fill" : "cart.fill")
                    .font(.caption2.weight(.bold))
                Text(action == .goToHome ? "View Dashboard" : "Shopping List")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .fixedSize()
            .foregroundStyle(Color.pantriGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.pantriGreenLight)
            .clipShape(Capsule())
        }
    }

    private var botAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.pantriGreenLight)
                .frame(width: 28, height: 28)
            Image(systemName: "leaf.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.pantriGreen)
        }
    }

    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.pantriGreenLight)
                .frame(width: 28, height: 28)
            Image(systemName: "person.fill")
                .font(.caption)
                .foregroundStyle(Color.pantriGreen)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.pantriGreenLight)
                    .frame(width: 28, height: 28)
                Image(systemName: "leaf.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.pantriGreen)
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.pantriGreen.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animate ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.pantriSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onAppear { animate = true }

            Spacer(minLength: 50)
        }
    }
}

// MARK: - Waveform

struct WaveformView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 22)
    let timer = Timer.publish(every: 0.09, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { i in
                Capsule()
                    .fill(Color.pantriGreen)
                    .frame(width: 3, height: max(4, levels[i] * 34))
                    .animation(.spring(duration: 0.14), value: levels[i])
            }
        }
        .onReceive(timer) { _ in
            for i in 0..<levels.count {
                levels[i] = CGFloat.random(in: 0.15...1.0)
            }
        }
    }
}
