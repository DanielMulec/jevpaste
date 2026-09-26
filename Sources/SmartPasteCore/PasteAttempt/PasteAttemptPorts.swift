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

/// What a Paste Attempt applies besides the adapters: the Narrowing policy and the Pre-checks.
public struct PasteAttemptRules: Sendable {
    let narrowingPolicy: NarrowingPolicy
    let preCheck: any PreCheck

    public init(narrowingPolicy: NarrowingPolicy, preCheck: any PreCheck) {
        self.narrowingPolicy = narrowingPolicy
        self.preCheck = preCheck
    }
}
