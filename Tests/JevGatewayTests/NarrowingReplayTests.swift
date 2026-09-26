import Foundation
import Testing

@testable import JevGateway
@testable import SmartPasteCore

/// Replays recorded pastes of the spike's verdict design `r2b` (issue #49; `Fixtures/narrowing-replay.jsonl`, written
/// by `scripts/extract-narrowing-fixtures.py` from `spikes/narrowing/round2/results/raw.jsonl` on `spike/narrowing`)
/// through Core's Narrowing and this adapter's encoding, feeding Jev's recorded answers back step by step.
///
/// Byte-identical means: the body this adapter sends equals the spike's recorded request after one normalisation —
/// the spike sent `json.dumps(body)` (separators ", " and ": ", non-ASCII as `\uXXXX`); the fixture holds that body
/// parsed and re-serialised with `json.dumps(ensure_ascii=False, separators=(",", ":"))`, member order kept, without
/// the measurement-only `place` question. Same JSON value, same member order, same characters.
struct NarrowingReplayTests {
    @Test(arguments: RecordedPaste.all.map(\.cell))
    func everyRequestIsTheSpikesAndTheOutcomeIsTheSame(cell: String) throws {
        let paste = try #require(RecordedPaste.all.first { $0.cell == cell })
        let first = try #require(paste.calls.first)
        var narrowing = Narrowing(
            item: ClipboardItem(text: first.sourceDocument), context: first.targetContext, policy: .r2b
        )
        var action = narrowing.start()
        for (number, call) in paste.calls.enumerated() {
            guard case .send(let request) = action else {
                Issue.record("call \(number): expected a request, got \(action)")
                return
            }
            let body = String(bytes: EvaluateRequestBody.data(for: request), encoding: .utf8)
            #expect(body == call.request, "call \(number) differs from the spike's request")
            let answers = try EvaluateResponse.answers(from: call.responseBody, to: request).get()
            action = narrowing.receive(answers)
        }
        #expect(action == paste.expectedAction)
    }

    @Test func theReplayCoversEveryShapeOfStep() {
        let cells = Set(RecordedPaste.all.map(\.cell))
        #expect(cells.count == 12)
        #expect(cells.isSuperset(of: ["K01_three_emails", "N03_list_300_lines", "H06_company_description"]))
    }
}

/// One recorded paste: every call's request and Jev's answers, and how the paste ended.
struct RecordedPaste {
    struct Call {
        let request: String
        let responseBody: Data
        let sourceDocument: String
        let targetContext: TargetContext
    }

    let cell: String
    let calls: [Call]
    let expectedAction: NarrowingAction

    static let all: [RecordedPaste] = {
        guard
            let url = Bundle.module.url(
                forResource: "narrowing-replay", withExtension: "jsonl", subdirectory: "Fixtures"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return text.split(separator: "\n").compactMap { OrderedJSONParser.parse($0.utf8).flatMap(RecordedPaste.init) }
    }()

    private init?(_ row: OrderedJSON) {
        guard let cell = row["cell"]?.stringValue, let calls = row["calls"]?.arrayElements,
            let outcome = row["outcome"]?.stringValue
        else { return nil }
        self.cell = cell
        self.calls = calls.compactMap(Self.call)
        switch outcome {
        case "paste": expectedAction = .pasteResult(row["final"]?.stringValue ?? "")
        case "nothing": expectedAction = .nothingFits
        default:
            let texts = row["chooser"]?.arrayElements?.compactMap(\.stringValue) ?? []
            expectedAction = .askUser(texts.map { Candidate(text: $0) })
        }
    }

    private static func call(_ recorded: OrderedJSON) -> Call? {
        guard let request = recorded["request"]?.stringValue, let answers = recorded["answers"],
            let body = OrderedJSONParser.parse(request.utf8), let state = body["state"],
            let source = state["source_document"]?.stringValue, let context = state["target_context"]
        else { return nil }
        let responseBody = Data(OrderedJSON.object([.init("answers", answers)]).rendered.utf8)
        return Call(
            request: request, responseBody: responseBody, sourceDocument: source, targetContext: targetContext(context)
        )
    }

    private static func targetContext(_ json: OrderedJSON) -> TargetContext {
        TargetContext(
            fieldLabel: json["field_label"]?.stringValue, placeholder: json["placeholder"]?.stringValue,
            sectionHeading: json["section_heading"]?.stringValue,
            siblingFieldLabels: json["sibling_field_labels"]?.arrayElements?.compactMap(\.stringValue) ?? [],
            surroundingText: json["surrounding_text"]?.stringValue ?? "", appName: json["app_name"]?.stringValue,
            windowTitle: json["window_title"]?.stringValue
        )
    }
}
