import Foundation
import Observation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

// MARK: - Speech to text

/// Vietnamese dictation. Prefers on-device recognition so it works with no signal.
@MainActor
@Observable
final class VoiceInput {
    enum Failure: Error { case denied, unavailable, audio }

    private(set) var isListening = false
    /// 30 recent input levels, 0…1, for the waveform.
    private(set) var levels: [CGFloat] = Array(repeating: 0, count: 30)
    private(set) var onDevice = false

    @ObservationIgnored private var engine: SpeechEngine?

    /// Available offline for Vietnamese on this device?
    static var supportsOffline: Bool {
        #if canImport(Speech)
        SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))?.supportsOnDeviceRecognition ?? false
        #else
        false
        #endif
    }

    static var isAuthorized: Bool {
        #if canImport(Speech)
        SFSpeechRecognizer.authorizationStatus() == .authorized
        #else
        false
        #endif
    }

    /// Streams partial transcripts into `onText` until `stop()` or silence ends recognition.
    func start(onText: @escaping @MainActor (String) -> Void, onEnd: @escaping @MainActor (Failure?) -> Void) async {
        #if canImport(Speech)
        guard await Self.requestPermissions() else { return onEnd(.denied) }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN")), recognizer.isAvailable else {
            return onEnd(.unavailable)
        }
        onDevice = recognizer.supportsOnDeviceRecognition
        let engine = SpeechEngine(recognizer: recognizer, onDevice: onDevice)
        do {
            try engine.start(
                onText: { text in Task { @MainActor in onText(text) } },
                onLevel: { level in Task { @MainActor [weak self] in self?.push(level) } },
                onEnd: { failed in Task { @MainActor [weak self] in self?.finish(); onEnd(failed ? .audio : nil) } })
            self.engine = engine
            isListening = true
        } catch {
            onEnd(.audio)
        }
        #else
        onEnd(.unavailable)
        #endif
    }

    func stop() {
        engine?.stop()
        finish()
    }

    private func finish() {
        engine = nil
        isListening = false
        levels = Array(repeating: 0, count: 30)
    }

    private func push(_ level: CGFloat) {
        levels.removeFirst()
        levels.append(level)
    }

    #if canImport(Speech)
    /// Nonisolated: TCC calls the completion on a background queue.
    nonisolated static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
    #endif
}

#if canImport(Speech)
/// Audio engine + recognition task. Callbacks arrive on audio/recognizer threads.
private final class SpeechEngine: @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private let audio = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?

    init(recognizer: SFSpeechRecognizer, onDevice: Bool) {
        self.recognizer = recognizer
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = onDevice
        request.addsPunctuation = true
    }

    func start(onText: @escaping @Sendable (String) -> Void, onLevel: @escaping @Sendable (CGFloat) -> Void,
               onEnd: @escaping @Sendable (Bool) -> Void) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw VoiceInput.Failure.audio }
        let request = self.request
        var tick = 0
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            tick += 1
            guard tick % 3 == 0, let data = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += data[i] * data[i] }
            let rms = sqrt(sum / Float(max(n, 1)))
            onLevel(CGFloat(min(1, rms * 12)))
        }
        audio.prepare()
        try audio.start()
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result { onText(result.bestTranscription.formattedString) }
            if error != nil || result?.isFinal == true {
                self?.teardown()
                onEnd(error != nil && result == nil)
            }
        }
    }

    func stop() {
        request.endAudio()
        teardown()
    }

    private func teardown() {
        if audio.isRunning {
            audio.stop()
            audio.inputNode.removeTap(onBus: 0)
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
#endif

// MARK: - Text to speech

/// Reads answers and emergency cards aloud with the system Vietnamese voice.
@MainActor
@Observable
final class Speaker {
    static let shared = Speaker()

    /// Identifies what is being read, so each "Đọc to" button can show its own state.
    private(set) var speakingID: String?

    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private lazy var delegate = SpeakerDelegate { [weak self] in self?.speakingID = nil }

    static var hasVietnameseVoice: Bool { AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix("vi") } }

    func toggle(_ text: String, id: String) {
        if speakingID == id { stop() } else { speak(text, id: id) }
    }

    func speak(_ text: String, id: String) {
        synth.delegate = delegate
        synth.stopSpeaking(at: .immediate)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        #endif
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "vi-VN")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speakingID = id
        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speakingID = nil
    }

    @ObservationIgnored private var spokenKeys: Set<String> = []

    /// Auto-read: speaks at most once per key (lazy lists re-create views when scrolling).
    func speakOnce(_ text: String, id: String, key: String) {
        guard spokenKeys.insert(id + key).inserted else { return }
        speak(text, id: id)
    }
}

private final class SpeakerDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let onDone: @MainActor () -> Void
    init(onDone: @escaping @MainActor () -> Void) { self.onDone = onDone }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { Task { @MainActor in onDone() } }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { Task { @MainActor in onDone() } }
}

// MARK: - Whistle

/// Loops a bundled, recorded whistle at full player volume (never synthesized).
/// Add `whistle.m4a` (or .caf/.wav/.mp3) to the app bundle.
@MainActor
final class WhistlePlayer {
    static let shared = WhistlePlayer()
    private var player: AVAudioPlayer?

    static var assetURL: URL? {
        for ext in ["m4a", "caf", "wav", "mp3"] {
            if let url = Bundle.main.url(forResource: "whistle", withExtension: ext) { return url }
        }
        return nil
    }

    /// Returns false when the asset is missing or can't play.
    func start() -> Bool {
        guard let url = Self.assetURL, let p = try? AVAudioPlayer(contentsOf: url) else { return false }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        p.numberOfLoops = -1
        p.volume = 1
        player = p
        return p.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
