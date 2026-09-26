import Foundation

// MARK: - Platform ports (implemented per platform, everything else is shared logic)

/// SQLite FTS5 over the pack. iOS: system SQLite. Android: bundled SQLite (FTS5 is not guaranteed in the OS build).
public protocol LexicalRetriever: Sendable {
    func search(_ query: NormalizedQuery, route: Route, limit: Int) async throws -> [LexicalHit]
}

/// Query embedding. Same .tflite model on both platforms (LiteRT) so vectors match across iOS/Android.
/// multilingual-e5 requires the "query: " prefix here and "passage: " in the pack builder.
public protocol QueryEmbedder: Sendable {
    func embed(_ text: String) async throws -> [Float]
}

public protocol KnowledgeStore: Sendable {
    func chunkMeta(ids: [String]) async throws -> [String: ChunkMeta]
    func parents(ids: [String]) async throws -> [String: ParentBlock]
    func emergencyCard(intent: String) async throws -> EmergencyCard?
}

/// LLM runtime. Default: LiteRT-LM (Swift API on iOS, Kotlin API on Android), same .litertlm file.
/// Challenger adapter: llama.cpp (GGUF) for Qwen3.5. Chosen by the bake-off, not by this interface.
public protocol LocalLanguageModel: Sendable {
    func generate(_ prompt: Prompt, maxTokens: Int) -> AsyncThrowingStream<String, Error>
}

// MARK: - Events: the evidence-first UX contract

/// The UI renders events in arrival order. The Emergency Card and the sources appear in ~150 ms,
/// long before the first LLM token. Kotlin: `sealed class PipelineEvent` + `Flow<PipelineEvent>`.
public enum PipelineEvent: Sendable, Equatable {
    case emergencyCard(EmergencyCard)
    case evidence([EvidenceBlock])
    case notice(String)
    case partial(StructuredAnswer)
    case final(ValidatedAnswer)
    /// Retrieval not confident, or LLM disabled: UI shows sources + "không đủ căn cứ" state.
    case noAnswer(reason: NoAnswerReason)
}

public enum NoAnswerReason: String, Sendable, Equatable {
    case insufficientEvidence, llmDisabled
}

// MARK: - Pipeline

public struct RAGPipeline: Sendable {
    public let normalizer: QueryNormalizer
    public let router: RiskRouter
    public let lexical: LexicalRetriever
    public let embedder: QueryEmbedder
    public let dense: DenseIndex
    public let store: KnowledgeStore
    public let llm: LocalLanguageModel?
    public let installedTier: ModelTier

    let fuser = HybridFuser()
    let selector = ContextSelector()
    let gate = ConfidenceGate()
    let prompts = PromptBuilder()
    let validator = GroundingValidator()
    let policy = DevicePolicy()

    public init(normalizer: QueryNormalizer, router: RiskRouter, lexical: LexicalRetriever, embedder: QueryEmbedder,
                dense: DenseIndex, store: KnowledgeStore, llm: LocalLanguageModel?, installedTier: ModelTier) {
        self.normalizer = normalizer
        self.router = router
        self.lexical = lexical
        self.embedder = embedder
        self.dense = dense
        self.store = store
        self.llm = llm
        self.installedTier = installedTier
    }

    public func answer(_ text: String, state: ConversationState, device: DeviceSnapshot) -> AsyncThrowingStream<PipelineEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(text, state: state, device: device) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func run(_ text: String, state: ConversationState, device: DeviceSnapshot,
             emit: @Sendable (PipelineEvent) -> Void) async throws {
        // Stage A: routing (rules, < 1 ms)
        let query = normalizer.normalize(text)
        let route = router.route(query, statedRegion: state.environment)

        // Emergency bypass: reviewed card first, never blocked by model loading.
        if let intent = route.emergencyIntent, let card = try await store.emergencyCard(intent: intent) {
            emit(.emergencyCard(card))
        }

        // Stage B: hybrid retrieval, both channels in parallel
        let retrievalText = [text, state.retrievalHint].filter { !$0.isEmpty }.joined(separator: " ")
        async let lexicalHits = lexical.search(query, route: route, limit: route.topK)
        async let queryVector = embedder.embed(retrievalText)
        let denseIds = dense.topK(try await queryVector, k: route.topK).map(\.id)
        let lexHits = try await lexicalHits

        // Stage C: fusion, cleanup, packing
        let ids = Array(Set(lexHits.map(\.chunkId) + denseIds))
        let meta = try await store.chunkMeta(ids: ids)
        let fused = fuser.fuse(lexical: lexHits, dense: denseIds, meta: meta, route: route)
        let parents = try await store.parents(ids: Array(Set(fused.map(\.meta.parentId))))
        let plan = policy.plan(installed: installedTier, device: device, route: route)
        let evidence = selector.pack(fused, parents: parents, route: route, budget: plan.budget)

        emit(.evidence(evidence))
        if let notice = plan.notice { emit(.notice(notice)) }

        guard gate.isSupported(evidence, route: route) else { emit(.noAnswer(reason: .insufficientEvidence)); return }
        guard plan.llmEnabled, let llm else { emit(.noAnswer(reason: .llmDisabled)); return }

        // Stage D: constrained generation, streamed
        let prompt = prompts.build(query: query, state: state, evidence: evidence)
        var parser = AnswerParser()
        for try await delta in llm.generate(prompt, maxTokens: plan.maxOutputTokens) {
            try Task.checkCancellation()
            emit(.partial(parser.feed(delta)))
        }
        emit(.final(validator.validate(parser.finish(), evidence: evidence, route: route)))
    }
}
