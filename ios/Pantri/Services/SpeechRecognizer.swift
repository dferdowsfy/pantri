import Foundation
import Speech
import AVFoundation

// MARK: - Speech Recognizer

/// Wraps Apple's SFSpeechRecognizer for live, on-device voice-to-text.
/// Publishes a live transcript string as the user speaks.
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

    // MARK: - Init

    init() {
        recognizer = SFSpeechRecognizer(locale: .current)
        Task { await requestPermission() }
    }

    // MARK: - Permissions

    @MainActor
    func requestPermission() async {
        // Speech permission
        let speechGranted = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        // Mic permission
        let micGranted = await AVAudioApplication.requestRecordPermission()

        isAvailable = speechGranted && micGranted && (recognizer?.isAvailable ?? false)
        if !isAvailable {
            errorMessage = "Microphone or speech permission not granted."
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard isAvailable, !isListening else { return }

        reset()
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
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            if let error {
                // Ignore cancellation errors (triggered by stopListening)
                let nsError = error as NSError
                let isCancelled = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
                if !isCancelled {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                }
                self.stopEngine()
            }
        }

        isListening = true
    }

    func stopListening() {
        stopEngine()
    }

    // MARK: - Private helpers

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func stopEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        DispatchQueue.main.async {
            self.isListening = false
        }
        // Deactivate audio session so other audio (music, etc.) can resume
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func reset() {
        transcript = ""
        errorMessage = nil
        stopEngine()
    }
}
