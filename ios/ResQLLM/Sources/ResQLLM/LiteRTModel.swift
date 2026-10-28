import Foundation
import LiteRTLM
import ResQCore
import os
#if canImport(UIKit)
import UIKit
#endif

/// Gemma 4 E4B on LiteRT-LM, Metal GPU. Every setting below was measured with bench/run_litert.py,
/// not guessed (docs/03 §13):
/// - Speculative decoding (the model's own multi-token drafter): on an M3 Pro, decode 42 → 99 tok/s,
///   first action line 2.8 → 1.8 s, 100 → 59 J per answer, same pass rate on all three bench sets.
///   With it on, LiteRT-LM ignores the sampler and gives the same answer every time.
/// - KV cache left at the model's 4096. At 3072 the answers to long prompts (1.4K+ tokens) got worse:
///   the user-style bench fell from 100% to 89%.
/// - Compiled GPU programs and weights go to Caches/ (2.2 GB, purgeable): load takes 0.5 s instead of 7.6 s.
///   Call `prewarm()` once right after the model download so no user waits for the compile.
/// Core AI / Core ML were not chosen: the published Core AI build of this model decodes at 15 tok/s on an
/// iPhone 17 Pro GPU (LiteRT-LM: 22–25 without speculative decoding) and has no Neural Engine path.
///
/// The engine loads on first use (`prewarm()` also lets the UI start it while the user types) and is dropped
/// when the app goes to the background or memory runs low: a 3.4 GB process is the first one iOS kills.
/// Stopping the stream stops the GPU at once. Signposts (Points of Interest) mark load, prefill and decode
/// so Instruments shows them next to the Power Profiler and Metal tracks.
public actor LiteRTModel: LocalLanguageModel {
    public let modelURL: URL
    private var engine: Engine?
    private let signposter = OSSignposter(subsystem: "com.huzastudio.resq", category: .pointsOfInterest)
    private var observers: [NSObjectProtocol] = []

    public init(modelURL: URL) {
        self.modelURL = modelURL
    }

    /// Releases the engine when the app leaves the foreground or iOS warns about memory.
    public func releaseOnBackgroundAndMemoryWarning() {
        #if canImport(UIKit)
        guard observers.isEmpty else { return }
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.didReceiveMemoryWarningNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                Task { await self?.release() }
            })
        }
        #endif
    }

    /// Loads the model ahead of the first question (about 0.5 s with a warm cache, seconds on a cold one).
    public func prewarm() async throws {
        _ = try await loadedEngine()
    }

    public func release() {
        engine = nil
    }

    public nonisolated func generate(_ prompt: Prompt, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.run(prompt, maxTokens: maxTokens) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func loadedEngine() async throws -> Engine {
        if let engine { return engine }
        let state = signposter.beginInterval("load")
        defer { signposter.endInterval("load", state) }
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("litert")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let e = Engine(engineConfig: try EngineConfig(modelPath: modelURL.path, backend: .gpu, cacheDir: cache.path))
        try await e.initialize()
        engine = e
        return e
    }

    /// Same sampling as the bench (bench/run.py OPTIONS), thinking off.
    private func run(_ prompt: Prompt, maxTokens: Int, emit: @Sendable (String) -> Void) async throws {
        let conversation = try await loadedEngine().createConversation(with: ConversationConfig(
            systemMessage: Message(prompt.system, role: .system),
            samplerConfig: try SamplerConfig(topK: 40, topP: 0.9, temperature: 0.2),
            thinkingConfig: ThinkingConfig(enableThinking: false),
            enableSpeculativeDecoding: true))
        var phase = signposter.beginInterval("prefill")
        var decoding = false
        defer { signposter.endInterval(decoding ? "decode" : "prefill", phase) }
        try await withTaskCancellationHandler {
            for try await chunk in conversation.sendMessageStream(Message(prompt.user), maxOutputTokens: maxTokens) {
                try Task.checkCancellation()
                let text = chunk.toString
                guard !text.isEmpty else { continue }
                if !decoding {
                    signposter.endInterval("prefill", phase)
                    phase = signposter.beginInterval("decode")
                    decoding = true
                }
                emit(text)
            }
        } onCancel: {
            try? conversation.cancel()
        }
    }
}
