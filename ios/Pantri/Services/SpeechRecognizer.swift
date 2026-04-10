import Foundation
import Speech
import AVFoundation

// MARK: - Speech Recognizer

/// Wraps Apple's SFSpeechRecognizer for live, on-device voice-to-text.
/// Automatically restarts when Apple's recognition session times out,
/// keeping the microphone open until the caller explicitly calls `stopListening()`.
@Observable
final class SpeechRecognizer {

    // MARK: - Published State

    var transcript: String = ""
    var isListening: Bool = false
    var isAvailable: Bool = false
    var errorMessage: String?

    // MARK: - Private

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var shouldContinueListening = false
    private var accumulatedTranscript = ""

    // MARK: - Init

    init() {
        recognizer = SFSpeechRecognizer(locale: .current)
        Task { await requestPermission() }
    }

    // MARK: - Permissions

    @MainActor
    func requestPermission() async {
        let speechGranted = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()

        isAvailable = speechGranted && micGranted && (recognizer?.isAvailable ?? false)
        if !isAvailable {
            errorMessage = "Microphone or speech permission not granted."
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard isAvailable, !isListening else { return }
        shouldContinueListening = true
        accumulatedTranscript = ""
        transcript = ""
        errorMessage = nil
        tearDownEngine()
        beginSession()
    }

    func stopListening() {
        shouldContinueListening = false
        tearDownEngine()
        DispatchQueue.main.async {
            self.isListening = false
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Session lifecycle

    private func beginSession() {
        setupAudioSession()

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Audio engine failed to start."
            return
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let currentText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = self.accumulatedTranscript.isEmpty
                        ? currentText
                        : self.accumulatedTranscript + " " + currentText
                }
                if result.isFinal {
                    self.accumulatedTranscript = self.transcript
                    self.restartSessionIfNeeded()
                    return
                }
            }

            if let error {
                let nsError = error as NSError
                let isCancelled = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
                if isCancelled { return }
                // Non-cancellation error → persist what we have and try to restart
                self.accumulatedTranscript = self.transcript
                self.restartSessionIfNeeded()
            }
        }

        DispatchQueue.main.async {
            self.isListening = true
        }
    }

    private func restartSessionIfNeeded() {
        tearDownEngine()
        guard shouldContinueListening else {
            DispatchQueue.main.async { self.isListening = false }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.shouldContinueListening else { return }
            self.beginSession()
        }
    }

    // MARK: - Helpers

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func tearDownEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}
