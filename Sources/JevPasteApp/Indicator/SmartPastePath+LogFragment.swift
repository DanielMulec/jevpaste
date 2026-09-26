import Foundation
import SmartPasteCore

extension SmartPastePath {
    /// The path in the outcome log line — numbers and fixed names only:
    /// `via=narrowing steps=3 calls=4 p=0.85 questions=2+f0,2+f2,s full=1 offer=dismissed`. Per step: the questions of
    /// its request, `+f<n>` when a follow-up choice went with n speculative next-step questions, `s` when a
    /// speculative answer decided it without a call. When Jev asked the user, `fill=<n> fillEnd=<why>` says how many
    /// fill choices filled the Candidate Chooser and why the fill ended (`keep`, `nothingFits`, `clock`, `failed`).
    /// `full=` counts requests in the full-text form (left out at 0), `offer=` how a No Suitable Match offer ended
    /// without Enter. Enter after No Suitable Match is a Direct Paste:
    /// `via=directPaste reason=enterAfterNoMatch p=0.12`.
    var logFragment: String {
        let probability = narrowing.decidingProbability.map { String(format: " p=%.2f", $0) } ?? ""
        if noSuitableMatchOfferEnd == .accepted { return "via=directPaste reason=enterAfterNoMatch" + probability }
        let steps = narrowing.steps.map(Self.fragment(of:)).joined(separator: ",")
        let fullText = narrowing.fullTextRequests > 0 ? " full=\(narrowing.fullTextRequests)" : ""
        let offer = noSuitableMatchOfferEnd.map { " offer=\($0)" } ?? ""
        let questions = steps.isEmpty ? "" : " questions=" + steps
        let fill = narrowing.chooserFill.map(Self.fragment(of:)) ?? ""
        return
            "via=narrowing steps=\(narrowing.steps.count) calls=\(calls)\(probability)\(questions)\(fill)\(fullText)"
            + offer
    }

    private static func fragment(of fill: ChooserFillTrace) -> String {
        " fill=\(fill.calls)" + (fill.end.map { " fillEnd=\($0)" } ?? "")
    }

    private static func fragment(of step: NarrowingTrace.Step) -> String {
        if step.isSpeculative { return "s" }
        return "\(step.questions)" + (step.followUpSpeculativeQuestions.map { "+f\($0)" } ?? "")
    }
}
