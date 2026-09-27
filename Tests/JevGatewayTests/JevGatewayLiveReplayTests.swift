import CryptoKit
import Foundation
import Testing

@testable import JevGateway
@testable import SmartPasteCore

/// Decision 8's live proof: the 14 recorded Narrowing cells (`Fixtures/narrowing-replay.jsonl`) driven through Core's
/// Narrowing with **live** answers from one Jev Provider, each ending as the spike's paste ended — the same Paste
/// Result, No Suitable Match, or asking the user (the chooser's fill starts). Probabilities may differ.
///
/// Only with `JEVPASTE_LIVE_JEV=1` and the provider's key file. One line per cell on standard error: the fixture's
/// cell id, the outcome kind, whether it is the recorded one, each question's chosen probability in the last call
/// (live and recorded), the calls and the latency — never a key or any document or excerpt text.
@Suite(.serialized) struct JevGatewayLiveReplayTests {
    @Test(.enabled(if: LiveJev.isEnabled(for: .vercelAIGateway), "JEVPASTE_LIVE_JEV=1 and a Gateway key file"))
    func everyRecordedCellEndsTheSameThroughTheGateway() async throws {
        try await replayEveryCell(through: .vercelAIGateway)
    }

    @Test(.enabled(if: LiveJev.isEnabled(for: .typesafeDirect), "JEVPASTE_LIVE_JEV=1 and a Typesafe key file"))
    func everyRecordedCellEndsTheSameThroughTypesafeDirect() async throws {
        try await replayEveryCell(through: .typesafeDirect)
    }

    /// The harness itself, offline: fed the spike's recorded answers, every cell ends as recorded.
    @Test func fedTheRecordedAnswersTheHarnessEndsEveryCellAsRecorded() async throws {
        for paste in RecordedPaste.all {
            let replayed = try await LiveReplay.run(paste, through: RecordedAnswers(paste))
            #expect(replayed.outcome == LiveReplay.Outcome(recorded: paste), "\(paste.cell)")
            #expect(replayed.lastProbabilities == LiveReplay.recordedProbabilities(of: paste), "\(paste.cell)")
        }
    }

    private func replayEveryCell(through provider: JevProvider) async throws {
        let service = try LiveJev.service(for: provider)
        #expect(RecordedPaste.all.count == 14)
        var same = 0
        for paste in RecordedPaste.all {
            let live = try await LiveReplay.run(paste, through: service)
            let isSame = LiveReplay.accepts(live.outcome, for: paste)
            same += isSame ? 1 : 0
            LiveJev.report(
                "live-replay",
                "provider=\(provider.rawValue) cell=\(paste.cell) outcome=\(live.outcome.name) accepted=\(isSame) "
                    + "result=\(live.outcome.digest) recorded=\(LiveReplay.Outcome(recorded: paste).digest) "
                    + "p=\(live.lastProbabilities) p_recorded=\(LiveReplay.recordedProbabilities(of: paste)) "
                    + "calls=\(live.calls) latency_ms=\(live.latencies.map(String.init).joined(separator: "+"))"
            )
            #expect(isSame, "\(paste.cell) ended \(live.outcome.name) through \(provider.rawValue)")
        }
        LiveJev.report("live-replay", "provider=\(provider.rawValue) accepted=\(same)/\(RecordedPaste.all.count)")
    }
}

/// One recorded paste replayed with live answers.
enum LiveReplay {
    enum Outcome: Equatable {
        case paste(String)
        case nothing
        case ask
        case stopped(NarrowingReply)

        init(recorded paste: RecordedPaste) {
            switch paste.expectedAction {
            case .pasteResult(let text): self = .paste(text)
            case .nothingFits: self = .nothing
            default: self = .ask
            }
        }

        /// A Paste Result's first 8 SHA-256 hex digits, so two results compare in the log without their text; `-`
        /// for every other outcome.
        var digest: String {
            guard case .paste(let text) = self else { return "-" }
            return SHA256.hash(data: Data(text.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
        }

        /// `paste:<digest>`, or the kind for every other outcome.
        var key: String {
            if case .paste = self { return "paste:" + digest }
            return name
        }

        /// The kind only: a Paste Result's text is compared, never printed.
        var name: String {
            switch self {
            case .paste: "paste"
            case .nothing: "nothing"
            case .ask: "ask"
            case .stopped(let reply): "stopped(\(reply))"
            }
        }
    }

    /// Near-tie cells whose outcome flips between runs on **both** providers (their recorded probabilities sit near
    /// 0.5). Each also accepts the one alternative observed; the fixture is unchanged. Tally from
    /// docs/acceptance/run-2026-09-27-typesafe-direct.log, 5 live runs per provider:
    /// B06_biography — Gateway nothing 1 / paste 4, Typesafe nothing 3 / paste 2, every paste sha8 2bcda570;
    /// N03_list_300_lines — Gateway recorded paste 5, Typesafe recorded paste 4 / nothing 1.
    static let nearTieAlternatives: [String: Set<String>] = [
        "B06_biography": ["paste:2bcda570"], "N03_list_300_lines": ["nothing"],
    ]

    /// The recorded outcome, or — for a near-tie cell only — its observed alternative.
    static func accepts(_ outcome: Outcome, for paste: RecordedPaste) -> Bool {
        outcome == Outcome(recorded: paste) || nearTieAlternatives[paste.cell]?.contains(outcome.key) == true
    }

    struct Result {
        let outcome: Outcome
        let calls: Int
        let latencies: [Int]
        let lastProbabilities: String
    }

    static func run(_ paste: RecordedPaste, through service: any DecisionService) async throws -> Result {
        let first = try #require(paste.calls.first)
        var narrowing = Narrowing(
            item: ClipboardItem(text: first.sourceDocument), context: first.targetContext, policy: .r2b
        )
        var action = narrowing.start()
        var latencies: [Int] = []
        var lastProbabilities = "-"
        while case .send(let request) = action, narrowing.trace.chooserFill == nil {
            let started = ContinuousClock.now
            let narrowingReply = await reply(from: service, to: request)
            latencies.append(LiveJev.milliseconds(.now - started))
            guard case .answered(let answers) = narrowingReply else {
                return Result(
                    outcome: .stopped(narrowingReply), calls: latencies.count, latencies: latencies,
                    lastProbabilities: lastProbabilities)
            }
            lastProbabilities = chosenProbabilities(answers, order: request.questions.map(\.id))
            action = narrowing.receive(answers)
        }
        let outcome: Outcome =
            switch action {
            case .pasteResult(let text): .paste(text)
            case .nothingFits: .nothing
            default: .ask
            }
        return Result(
            outcome: outcome, calls: latencies.count, latencies: latencies,
            lastProbabilities: lastProbabilities)
    }

    /// The recorded last call's chosen probabilities, read the same way.
    static func recordedProbabilities(of paste: RecordedPaste) -> String {
        guard let last = paste.calls.last, let request = OrderedJSONParser.parse(last.request.utf8),
            let ids = request["questions"]?.objectMembers?.map(\.key)
        else { return "-" }
        let answers = ids.reduce(into: [String: ChoiceAnswer]()) { answers, id in
            guard let answer = OrderedJSONParser.parse(last.responseBody)?["answers"]?[id],
                let choice = answer["choice"]?.stringValue
            else { return }
            let probabilities = answer["probabilities"]?.objectMembers?.compactMap { member -> OptionProbability? in
                guard case .number(let probability) = member.value else { return nil }
                return OptionProbability(optionID: member.key, probability: probability)
            }
            answers[id] = ChoiceAnswer(choice: choice, probabilities: probabilities ?? [])
        }
        return chosenProbabilities(answers, order: ids)
    }

    /// Each question's chosen option's probability, in question order, two decimals: `0.97/0.88`.
    private static func chosenProbabilities(_ answers: [String: ChoiceAnswer], order: [String]) -> String {
        order.compactMap { id in
            answers[id].map { answer in
                let probability = answer.probabilities.first { $0.optionID == answer.choice }?.probability ?? -1
                return String(format: "%.2f", probability)
            }
        }.joined(separator: "/")
    }
}

/// Answers each call with the spike's recorded answers to that call, in order.
private struct RecordedAnswers: DecisionService {
    private actor CallCounter {
        private var count = 0

        func next() -> Int {
            defer { count += 1 }
            return count
        }
    }

    private let paste: RecordedPaste
    private let counter = CallCounter()

    init(_ paste: RecordedPaste) {
        self.paste = paste
    }

    func evaluate(_ request: NarrowingRequest, reply: @escaping @MainActor @Sendable (NarrowingReply) -> Void) {
        Task {
            let index = await counter.next()
            guard paste.calls.indices.contains(index),
                case .success(let answers) = EvaluateResponse.answers(
                    from: paste.calls[index].responseBody, to: request)
            else { return await reply(.failed) }
            await reply(.answered(answers))
        }
    }
}
