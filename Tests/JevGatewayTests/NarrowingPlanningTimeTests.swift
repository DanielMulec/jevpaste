import Foundation
import Testing

@testable import JevGateway
@testable import SmartPasteCore

/// How long Core's synchronous Narrowing work takes per step — planning the request, and for a follow-up the
/// speculative next steps of its top pieces — on the recorded pastes and on a copy too big for one call. It runs on
/// the main actor, so while it runs the indicator cannot appear and a click cannot cancel.
///
/// Only with `JEVPASTE_PLANNING_TIME=1` (`make planning-time`, a release build): the ceilings are release-build
/// targets, which a debug build does not meet.
@Suite(.serialized) struct NarrowingPlanningTimeTests {
    private static let isEnabled = ProcessInfo.processInfo.environment["JEVPASTE_PLANNING_TIME"] == "1"
    /// The recorded 300-line list plans its steps within this; every other recorded paste within `ordinaryCeiling`.
    private static let longListCeiling = Duration.milliseconds(100)
    private static let ordinaryCeiling = Duration.milliseconds(20)
    /// A copy too big for one call only has to reach Jev's refusal.
    private static let tooBigCeiling = Duration.milliseconds(250)

    @Test(.enabled(if: isEnabled, "set JEVPASTE_PLANNING_TIME=1 (make planning-time)"))
    func everyRecordedStepIsPlannedWithinItsCeiling() throws {
        for paste in RecordedPaste.all {
            let first = try #require(paste.calls.first)
            var narrowing = Narrowing(
                item: ClipboardItem(text: first.sourceDocument), context: first.targetContext, policy: .r2b
            )
            var times = [Duration]()
            var action = Self.timed(&times) { narrowing.start() }
            for call in paste.calls {
                guard case .send(let request) = action else { break }
                let answers = try EvaluateResponse.answers(from: call.responseBody, to: request).get()
                action = Self.timed(&times) { narrowing.receive(answers) }
            }
            let slowest = times.max() ?? .zero
            let ceiling = paste.cell.hasPrefix("N03") ? Self.longListCeiling : Self.ordinaryCeiling
            Self.report("\(paste.cell) steps=\(times.count) slowest=\(slowest) ceiling=\(ceiling)")
            #expect(slowest <= ceiling, "\(paste.cell)")
        }
    }

    @Test(.enabled(if: isEnabled, "set JEVPASTE_PLANNING_TIME=1 (make planning-time)"))
    func aCopyTooBigForOneCallIsPlannedWithinItsCeiling() {
        var narrowing = Narrowing(
            item: ClipboardItem(text: Self.logList(lines: 3000)), context: TargetContext(fieldLabel: "Code"),
            policy: .r2b
        )
        var times = [Duration]()

        let action = Self.timed(&times) { narrowing.start() }

        let slowest = times.max() ?? .zero
        Self.report("too-big-3000-lines steps=1 slowest=\(slowest) ceiling=\(Self.tooBigCeiling)")
        guard case .send = action else {
            Issue.record("expected a request, got \(action)")
            return
        }
        #expect(slowest <= Self.tooBigCeiling)
    }

    /// A copy near Jev's limit (a long list, like N03 but longer, still within one call): the first step, and the step
    /// after Jev picked a piece in every choice — which also checks that pick byte for byte against the whole copy.
    @Test(.enabled(if: isEnabled, "set JEVPASTE_PLANNING_TIME=1 (make planning-time)"))
    func aCopyNearJevsLimitIsPlannedWithinTheLongListCeiling() {
        let copy = Self.logList(lines: Self.nearLimitLines)
        let context = TargetContext(fieldLabel: "Code")
        let firstStepFitsJev = StepPlanner(copy: copy, context: context, policy: .r2b).stepRequest(on: copy[...])
            .fitsJev
        #expect(firstStepFitsJev)
        var narrowing = Narrowing(item: ClipboardItem(text: copy), context: context, policy: .r2b)
        var times = [Duration]()

        guard case .send(let request) = Self.timed(&times, { narrowing.start() }) else {
            Issue.record("expected a first request")
            return
        }
        let answers = Dictionary(
            uniqueKeysWithValues: request.questions.compactMap { question -> (String, ChoiceAnswer)? in
                question.options.dropLast(2).last.map { (question.id, Self.certain($0.id)) }
            })
        let next = Self.timed(&times) { narrowing.receive(answers) }

        let slowest = times.max() ?? .zero
        Self.report(
            "near-limit-\(Self.nearLimitLines)-lines steps=\(times.count) questions=\(request.questions.count) "
                + "slowest=\(slowest) ceiling=\(Self.longListCeiling)")
        guard case .send = next else {
            Issue.record("expected the next request, got \(next)")
            return
        }
        #expect(slowest <= Self.longListCeiling)
    }

    /// Lines of the near-limit list: its first request still fits Jev by the size model.
    private static let nearLimitLines = 400

    /// A synthetic log excerpt: `lines` lines of timestamps, levels and numbers.
    private static func logList(lines: Int) -> String {
        (0..<lines).map { "2026-09-12 08:00:\($0 % 60) INFO sync-\($0 % 5) batch flushed in \($0) ms" }
            .joined(separator: "\n")
    }

    private static func certain(_ optionID: String) -> ChoiceAnswer {
        ChoiceAnswer(choice: optionID, probabilities: [OptionProbability(optionID: optionID, probability: 1)])
    }

    private static func timed(_ times: inout [Duration], _ work: () -> NarrowingAction) -> NarrowingAction {
        let started = ContinuousClock.now
        let action = work()
        times.append(ContinuousClock.now - started)
        return action
    }

    private static func report(_ line: String) {
        FileHandle.standardError.write(Data("[planning-time] \(line)\n".utf8))
    }
}
