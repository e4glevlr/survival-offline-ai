import Foundation
import Observation
import ResQCore

/// What the chat screen needs from the engine. Production: `PipelineResponder` over `RAGPipeline`.
public protocol AnswerResponder: Sendable {
    func answer(_ text: String, state: ConversationState) -> AsyncThrowingStream<PipelineEvent, Error>
}

public struct PipelineResponder: AnswerResponder {
    let pipeline: RAGPipeline
    let device: @Sendable () -> DeviceSnapshot

    public init(pipeline: RAGPipeline, device: @escaping @Sendable () -> DeviceSnapshot) {
        self.pipeline = pipeline
        self.device = device
    }

    public func answer(_ text: String, state: ConversationState) -> AsyncThrowingStream<PipelineEvent, Error> {
        pipeline.answer(text, state: state, device: device())
    }
}

/// One assistant turn, built up event by event (evidence-first).
public struct AssistantTurn: Equatable, Sendable {
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
}

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage] = []
    public var draft = ""
    public private(set) var isBusy = false
    public var state = ConversationState()

    private let responder: AnswerResponder
    private var task: Task<Void, Never>?

    public init(responder: AnswerResponder) {
        self.responder = responder
    }

    public func send(_ text: String? = nil) {
        let q = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isBusy else { return }
        draft = ""
        isBusy = true
        messages.append(ChatMessage(id: UUID(), role: .user(q)))
        let id = UUID()
        messages.append(ChatMessage(id: id, role: .assistant(AssistantTurn())))

        let stream = responder.answer(q, state: state)
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
