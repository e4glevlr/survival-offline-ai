// Smoke and timing run of ios/ResQLLM on a Mac: same Swift adapter, same settings as the iPhone build.
// Prints time to first token, total time and what AnswerParser made of each answer.
//
//   python3 bench/run_litert.py --model x --name x --dump-prompts /tmp/prompts.json
//   swift run -c release --package-path bench/LiteRTSwift LiteRTSwift ~/models/litert/gemma-4-E4B-it.litertlm /tmp/prompts.json [n]
//
// To see the load / prefill / decode signposts, record it with Instruments:
//   xcrun xctrace record --template "Time Profiler" --launch -- .build/release/LiteRTSwift <same args>
import Foundation
import ResQCore
import ResQLLM

struct Item: Decodable { let id: String; let system: String; let user: String }

let args = CommandLine.arguments
let model = LiteRTModel(modelURL: URL(fileURLWithPath: (args[1] as NSString).expandingTildeInPath))
let items = try JSONDecoder().decode([Item].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
let n = args.count > 3 ? Int(args[3])! : items.count

let clock = ContinuousClock()
let load = try await clock.measure { try await model.prewarm() }
print("load \(load)")
for item in items.prefix(n) {
    let start = clock.now
    var ttft: Duration?
    var parser = AnswerParser()
    for try await delta in model.generate(Prompt(system: item.system, user: item.user), maxTokens: 512) {
        if ttft == nil { ttft = clock.now - start }
        parser.feed(delta)
    }
    let a = parser.finish()
    let total = clock.now - start
    print(item.id.padding(toLength: 24, withPad: " ", startingAt: 0),
          "ttft", ttft.map { String(format: "%.2fs", Double($0.components.attoseconds) / 1e18 + Double($0.components.seconds)) } ?? "-",
          "total", String(format: "%.1fs", Double(total.components.seconds) + Double(total.components.attoseconds) / 1e18),
          "status", a.status.map { "\($0)" } ?? "-", "actions", a.immediateActions.count)
}
