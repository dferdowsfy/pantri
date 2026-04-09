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

    var body: some View {
        ZStack {
            Color.pantriOrange.ignoresSafeArea()
            backgroundShapes

            VStack(spacing: 0) {
                // ── Nav bar ───────────────────────────────────────────
                chatNavBar

                // ── Messages ──────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        // Increased bottom padding so content doesn't hide behind input bar
                        .padding(.bottom, keyboard.isVisible ? 100 : 180)
                    }
                    .opacity(viewModel.isVoiceMode ? 0.0 : 1.0)
                    .allowsHitTesting(!viewModel.isVoiceMode)
                    .onTapGesture {
                        // Dismiss keyboard when tapping message area
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(.spring(duration: 0.3)) {
                            if let lastId = viewModel.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // ── Centered Voice Mode Overlay ──────────────────────────
            if viewModel.isVoiceMode {
                centeredVoicePanel
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // ── Input bar anchored to keyboard ───────────────────────
            if !viewModel.isVoiceMode {
                VStack {
                    Spacer()
                    textInputBar
                        .padding(.bottom, keyboard.isVisible ? keyboard.keyboardHeight - 34 : 108)
                }
                .animation(.spring(duration: 0.3, bounce: 0.15), value: keyboard.keyboardHeight)
            }
        }
        .onChange(of: speech.transcript) { _, newValue in
            viewModel.voiceTranscript = newValue
        }
    }

    // MARK: - Nav bar

    private var chatNavBar: some View {
        HStack {
            Text("Pantri Assistant")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.pantriText)

            Spacer()

            // Voice toggle
            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    handleVoiceToggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isVoiceMode ? "keyboard" : "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(viewModel.isVoiceMode ? "Text" : "Voice")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(viewModel.isVoiceMode ? Color.pantriGreenDark : Color.pantriGreen)
                .frame(width: 80, height: 44) // Explicit sizing
                .contentShape(Rectangle())
            }

            // Clear
            Button {
                speech.stopListening()
                viewModel.clearChat()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.pantriText.opacity(0.4))
                    .padding(8)
            }
            .disabled(viewModel.messages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Background shapes

    private var backgroundShapes: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.pantriGreen.opacity(0.10))
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * 0.5, y: -40)
                Circle()
                    .fill(Color.pantriGreen.opacity(0.06))
                    .frame(width: geo.size.width * 0.45)
                    .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.55)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Voice toggle

    private func handleVoiceToggle() {
        if viewModel.isVoiceMode {
            speech.stopListening()
            viewModel.toggleVoiceMode()
        } else {
            viewModel.toggleVoiceMode()
            // Immediate start for better responsiveness
            speech.startListening()
        }
    }

    // MARK: - Text input bar (anchors to keyboard like ChatGPT)

    private var textInputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your pantry…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.white.opacity(0.9))
                        .shadow(color: Color.pantriGreen.opacity(0.10), radius: 6, y: 2)
                )
                .submitLabel(.send)
                .onSubmit {
                    Task { await viewModel.sendMessage(context: modelContext) }
                }

            Button {
                Task { await viewModel.sendMessage(context: modelContext) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(viewModel.canSend ? Color.pantriOrangeAccent : Color.pantriGreen.opacity(0.3))
                    .contentShape(Circle())
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.pantriOrange.opacity(0.97)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        )
    }

    // MARK: - Centered Voice Panel

    private var centeredVoicePanel: some View {
        VStack(spacing: 40) {
            Spacer()

            ZStack {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                    if speech.isListening {
                        speech.stopListening()
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            let text = viewModel.voiceTranscript
                            if !text.isEmpty {
                                await viewModel.sendVoiceMessage(text, context: modelContext)
                            }
                        }
                    } else {
                        speech.startListening()
                    }
                } label: {
                    AnimatedGlobeView(isListening: speech.isListening)
                        .frame(width: 220, height: 220)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(speech.isListening ? 1.05 : 1.0)
                .animation(.spring(duration: 0.3), value: speech.isListening)

                // The static mic icon in front
                if !speech.isListening {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4)
                        .allowsHitTesting(false)
                }
            }

            VStack(spacing: 16) {
                Text(speech.isListening ? "Listening..." : "Tap to talk")
                    .font(.headline)
                    .foregroundStyle(Color.pantriGreenDark)

                // Transcript text
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

            // Action Buttons
            HStack(spacing: 40) {
                // Cancel
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        handleVoiceToggle()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.pantriText.opacity(0.6))
                            .frame(width: 64, height: 64)
                            .contentShape(Rectangle())
                        Text("Cancel")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.pantriText.opacity(0.6))
                    }
                }

                // Send
                Button {
                    let text = viewModel.voiceTranscript
                    speech.stopListening()
                    Task { await viewModel.sendVoiceMessage(text, context: modelContext) }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(viewModel.voiceTranscript.isEmpty ? Color.pantriGreen.opacity(0.4) : Color.pantriOrangeAccent)
                            .frame(width: 64, height: 64)
                            .contentShape(Rectangle())
                        Text("Ask")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(viewModel.voiceTranscript.isEmpty ? Color.pantriGreen.opacity(0.4) : Color.pantriOrangeAccent)
                    }
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
            ZStack {
                Circle()
                    .fill(Color.pantriGreenLight)
                    .frame(width: 80, height: 80)
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.pantriGreen)
            }
            VStack(spacing: 6) {
                Text("Ask about your pantry")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.pantriText)

                Text("Try: \"What am I running low on?\"\nor tap Voice to speak.")
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
                    .foregroundStyle(Color.pantriOrangeAccent)
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

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                        ? AnyShapeStyle(Color.pantriOrangeAccent)
                        : AnyShapeStyle(Color.white.opacity(0.85))
                )
                .foregroundStyle(isUser ? .white : Color.pantriText)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: isUser ? Color.pantriOrangeAccent.opacity(0.20) : Color.black.opacity(0.05), radius: 4, y: 2)

            if !isUser { Spacer(minLength: 50) } else { userAvatar }
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
                .fill(Color.pantriOrange)
                .frame(width: 28, height: 28)
            Image(systemName: "person.fill")
                .font(.caption)
                .foregroundStyle(Color.pantriOrangeAccent)
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
            .background(Color.white.opacity(0.85))
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
