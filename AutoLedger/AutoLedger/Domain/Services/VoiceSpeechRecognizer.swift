import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoiceSpeechRecognizer: ObservableObject {
    enum RecognitionState: Equatable {
        case idle
        case requestingPermission
        case listening
        case unavailable(String)
    }

    @Published private(set) var state: RecognitionState = .idle
    @Published private(set) var transcript = ""

    private let recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var startToken: UUID?

    init(locale: Locale = AppLanguagePreference.current.speechRecognitionLocale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    func toggle() {
        if isListening {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isListening else { return }
        let token = UUID()
        startToken = token
        state = .requestingPermission

        Task {
            let speechAllowed = await requestSpeechAuthorization()
            guard startToken == token else { return }
            guard speechAllowed else {
                state = .unavailable(String(localized: "voice_ledger_speech_permission_denied"))
                return
            }

            let microphoneAllowed = await requestMicrophoneAuthorization()
            guard startToken == token else { return }
            guard microphoneAllowed else {
                state = .unavailable(String(localized: "voice_ledger_microphone_permission_denied"))
                return
            }

            guard startToken == token else { return }
            do {
                try startRecognition()
            } catch {
                state = .unavailable(error.localizedDescription)
            }
        }
    }

    func stop() {
        stopRecognition(cancelTask: false)
    }

    func cancel() {
        stopRecognition(cancelTask: true)
    }

    private func stopRecognition(cancelTask: Bool) {
        startToken = nil
        let hadActiveEngine = audioEngine != nil
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            audioEngine = nil
        }
        recognitionRequest?.endAudio()
        if cancelTask {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        recognitionRequest = nil
        if hadActiveEngine {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                assertionFailure("AVAudioSession deactivation failed: \(error)")
            }
        }
        if isListening || state == .requestingPermission {
            state = .idle
        }
    }

    private func startRecognition() throws {
        stopRecognition(cancelTask: true)

        guard let recognizer, recognizer.isAvailable else {
            state = .unavailable(String(localized: "voice_ledger_speech_unavailable"))
            return
        }

        transcript = ""

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        engine.prepare()
        try engine.start()
        state = .listening
        startToken = nil

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stopRecognition(cancelTask: false)
                    }
                }
                if let error {
                    self.state = .unavailable(error.localizedDescription)
                    self.cancel()
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}
