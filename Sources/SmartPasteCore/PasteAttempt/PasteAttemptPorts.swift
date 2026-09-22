/// The adapters a Paste Attempt drives, one per seam.
public struct PasteAttemptPorts {
    let hotkey: any Hotkey
    let clipboard: any Clipboard
    let targetResolver: any TargetResolver
    let inserter: any Inserter
    let decisionService: any DecisionService
    let clock: any PasteAttemptClock
    let presenter: any PasteOutcomePresenter
    let chooser: any CandidateChooser

    public init(
        hotkey: any Hotkey,
        clipboard: any Clipboard,
        targetResolver: any TargetResolver,
        inserter: any Inserter,
        decisionService: any DecisionService,
        clock: any PasteAttemptClock,
        presenter: any PasteOutcomePresenter,
        chooser: any CandidateChooser
    ) {
        self.hotkey = hotkey
        self.clipboard = clipboard
        self.targetResolver = targetResolver
        self.inserter = inserter
        self.decisionService = decisionService
        self.clock = clock
        self.presenter = presenter
        self.chooser = chooser
    }
}

/// The local rules a Paste Attempt applies before and after asking Jev.
public struct PasteAttemptRules: Sendable {
    let candidateExtraction: any CandidateExtraction
    let preCheck: any PreCheck

    public init(candidateExtraction: any CandidateExtraction, preCheck: any PreCheck) {
        self.candidateExtraction = candidateExtraction
        self.preCheck = preCheck
    }
}
