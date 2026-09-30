import Foundation
import Observation
import ResQCore

/// One question as the engine sees it: text, optional photo, installed model and live device state.
public struct AnswerRequest: Sendable {
    public var text: String
    public var imageJPEG: Data?
    public var installed: ModelTier
    public var device: DeviceSnapshot

    public init(text: String, imageJPEG: Data? = nil, installed: ModelTier = .large,
                device: DeviceSnapshot = DeviceSnapshot(physicalMemoryBytes: 8 << 30)) {
        self.text = text
        self.imageJPEG = imageJPEG
        self.installed = installed
        self.device = device
    }
}

/// What the chat screen needs from the engine. Production: `PipelineResponder` over `RAGPipeline`.
public protocol AnswerResponder: Sendable {
    func answer(_ request: AnswerRequest, state: ConversationState) -> AsyncThrowingStream<PipelineEvent, Error>
}

public struct PipelineResponder: AnswerResponder {
    let pipeline: RAGPipeline

    public init(pipeline: RAGPipeline) {
        self.pipeline = pipeline
    }

    public func answer(_ request: AnswerRequest, state: ConversationState) -> AsyncThrowingStream<PipelineEvent, Error> {
        pipeline.answer(request.text, state: state, device: request.device)
    }
}

/// One assistant turn, built up event by event (evidence-first).
public struct AssistantTurn: Equatable, Sendable {
    /// The question this turn answers (for saving and reading aloud).
    public var question = ""
    public var card: EmergencyCard?
    public var evidence: [EvidenceBlock] = []
    public var notice: String?
    public var answer: StructuredAnswer?
    public var status: AnswerStatus?
    public var noAnswer: NoAnswerReason?
    public var isStreaming = true
    public var failed = false

    public init() {}

    mutating func apply(_ event: PipelineEvent) {
        switch event {
        case .emergencyCard(let c): card = c
        case .evidence(let e): evidence = e
        case .notice(let n): notice = n
        case .partial(let a): answer = a
        case .final(let v): answer = v.answer; status = v.status; isStreaming = false
        case .noAnswer(let r): noAnswer = r; isStreaming = false
        }
    }
}

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public enum Role: Sendable, Equatable { case user(String), assistant(AssistantTurn) }
    public let id: UUID
    public var role: Role
    public var image: Data? = nil
}

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage] = []
    public var draft = ""
    /// Photo attached to the next question (JPEG).
    public var attachment: Data?
    /// Kept in sync by the screen: settings + live sensors feed DevicePolicy.
    public var installed: ModelTier = .large
    public var device = DeviceSnapshot(physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory)
    public private(set) var isBusy = false
    public var state = ConversationState()

    private let responder: AnswerResponder
    private var task: Task<Void, Never>?

    public init(responder: AnswerResponder) {
        self.responder = responder
    }

    public func send(_ text: String? = nil) {
        let image = text == nil ? attachment : nil
        var q = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty, image != nil { q = "Đây là gì? Có nguy hiểm không?" }
        guard !q.isEmpty, !isBusy else { return }
        draft = ""
        if image != nil { attachment = nil }
        isBusy = true
        messages.append(ChatMessage(id: UUID(), role: .user(q), image: image))
        let id = UUID()
        var turn = AssistantTurn()
        turn.question = q
        messages.append(ChatMessage(id: id, role: .assistant(turn)))
        UserStore.shared.record(question: q, hasImage: image != nil)

        let request = AnswerRequest(text: q, imageJPEG: image, installed: installed, device: device)
        let stream = responder.answer(request, state: state)
        task = Task { [weak self] in
            do {
                for try await event in stream { self?.update(id) { $0.apply(event) } }
            } catch {
                self?.update(id) { $0.failed = true; $0.isStreaming = false }
            }
            self?.isBusy = false
        }
    }

    public func cancel() {
        task?.cancel()
        isBusy = false
    }

    public func newConversation() {
        cancel()
        messages = []
        state = ConversationState()
    }

    private func update(_ id: UUID, _ change: (inout AssistantTurn) -> Void) {
        guard let i = messages.firstIndex(where: { $0.id == id }), case .assistant(var turn) = messages[i].role else { return }
        change(&turn)
        messages[i].role = .assistant(turn)
    }
}
