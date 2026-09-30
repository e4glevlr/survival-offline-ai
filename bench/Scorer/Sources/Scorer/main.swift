import Foundation
import ResQCore

// stdin: one JSON object per line {key, critical, labels, deltas}
// stdout: one JSON object per line with the raw parse and the validated answer.
struct Input: Decodable { let key: String; let critical: Bool; let labels: [String]; let deltas: [String] }

func encode(_ i: AnswerItem?) -> Any {
    guard let i else { return NSNull() }
    return ["text": i.text, "citations": i.citations]
}

func encode(_ a: StructuredAnswer) -> [String: Any] {
    ["status": a.status?.rawValue ?? NSNull(), "summary": a.summary, "summaryCitations": a.summaryCitations,
     "actions": a.immediateActions.map { encode($0) }, "doNot": a.doNot.map { encode($0) },
     "escalation": encode(a.escalation)]
}

while let line = readLine(strippingNewline: true) {
    let input = try JSONDecoder().decode(Input.self, from: Data(line.utf8))
    var parser = AnswerParser()
    for d in input.deltas { parser.feed(d) }
    let raw = parser.finish()
    let evidence = input.labels.map {
        EvidenceBlock(label: $0, block: ParentBlock(parentId: $0, articleId: $0, sourceLabel: "", headingPath: "",
                                                   text: "", tokens: 0, trust: .a), score: 1)
    }
    let v = GroundingValidator().validate(raw, evidence: evidence, route: Route(risk: input.critical ? .critical : .normal))
    let out: [String: Any] = ["key": input.key, "raw": encode(raw), "validated": encode(v.answer),
                              "validatedStatus": v.status.rawValue, "dropped": v.droppedItems]
    print(String(decoding: try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]), as: UTF8.self))
}
