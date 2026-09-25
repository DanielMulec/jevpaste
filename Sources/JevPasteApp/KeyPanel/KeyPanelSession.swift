import os

/// How the user closed a key-taking panel without answering it.
enum KeyPanelDismissal: String, Equatable {
    case escape = "esc"
    /// The panel stopped being key: the user clicked another window or app.
    case clickAway = "click-away"
}

/// One question asked in a key-capable, non-activating panel that took key focus from the Bound Target's app — the
/// Candidate Chooser's choice or the No Suitable Match offer. It is answered at most once: the session ends before
/// the panel closes (so the resign-key our own close causes, and any late key, find it answered), focus goes back
/// to the Target's app, and only then does the reply go out.
@MainActor
final class KeyPanelSession<Answer> {
    private struct Question {
        let processIdentifier: Int32
        let reply: @MainActor (Answer) -> Void
    }

    private let focusReturn: TargetAppFocusReturn
    private let log: Logger
    private var question: Question?

    init(focusReturn: TargetAppFocusReturn, log: Logger) {
        self.focusReturn = focusReturn
        self.log = log
    }

    /// Opens a question whose reply goes out after focus is back in the app with `processIdentifier`; `false`, and
    /// nothing changes, while another question is open.
    func begin(returningFocusTo processIdentifier: Int32, reply: @escaping @MainActor (Answer) -> Void) -> Bool {
        guard question == nil else { return false }
        question = Question(processIdentifier: processIdentifier, reply: reply)
        return true
    }

    /// Ends the open question, runs `closePanel`, returns focus, then replies with `answer`. No effect once ended.
    func answer(_ answer: Answer, closingPanel closePanel: () -> Void) {
        guard let question = end() else { return }
        closePanel()
        returnFocus(to: question.processIdentifier) {
            question.reply(answer)
        }
    }

    /// Ends the open question without a reply — its asker no longer waits — and returns focus to the Target's app.
    func abandon() {
        guard let question = end() else { return }
        returnFocus(to: question.processIdentifier) {}
    }

    private func end() -> Question? {
        defer { question = nil }
        return question
    }

    private func returnFocus(to processIdentifier: Int32, then completion: @escaping @MainActor () -> Void) {
        focusReturn.returnFocus(to: processIdentifier) { [log] result in
            switch result {
            case .frontmost(let elapsed):
                log.notice("target app reactivated in \(Int(elapsed.timeInterval * 1000), privacy: .public) ms")
            case .notFrontmost(let elapsed):
                log.notice("target app not frontmost after \(Int(elapsed.timeInterval * 1000), privacy: .public) ms")
            case .appGone:
                log.notice("target app gone")
            }
            completion()
        }
    }
}
