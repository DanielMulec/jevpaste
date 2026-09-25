/// The Pre-checks from "Choose paste lifecycle, cancellation and clipboard preservation": refuses a Paste Attempt
/// before anything leaves the machine when the Target is a secure field, or the Active Item is concealed or
/// holds a suspected secret (no editable Target is refused earlier, by the coordinator). The same secret rules
/// screen the surrounding text and the window title of the Target Context before it is sent.
public struct LocalPreChecks: PreCheck {
    private let secretRules: SuspectedSecretRules

    public init(secretRules: SuspectedSecretRules = .standard) {
        self.secretRules = secretRules
    }

    public func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal? {
        if target.isSecureField { return .secureField }
        if item.isConcealed || secretRules.firstMatch(in: item.text) != nil { return .suspectedSecret }
        return nil
    }

    public func screenedContext(of target: BoundTarget) -> ScreenedTargetContext {
        let context = target.context
        let withholdsSurroundingText = secretRules.firstMatch(in: context.surroundingText) != nil
        let withholdsWindowTitle = context.windowTitle.map { secretRules.firstMatch(in: $0) != nil } ?? false
        let screened = TargetContext(
            fieldLabel: context.fieldLabel, placeholder: context.placeholder, sectionHeading: context.sectionHeading,
            siblingFieldLabels: context.siblingFieldLabels,
            surroundingText: withholdsSurroundingText ? "" : context.surroundingText, appName: context.appName,
            windowTitle: withholdsWindowTitle ? nil : context.windowTitle
        )
        return ScreenedTargetContext(
            context: screened,
            note: Self.note(
                surroundingTextWithheld: withholdsSurroundingText,
                windowTitleWithheld: withholdsWindowTitle)
        )
    }

    private static func note(surroundingTextWithheld: Bool, windowTitleWithheld: Bool) -> PasteAttemptNote? {
        switch (surroundingTextWithheld, windowTitleWithheld) {
        case (true, true): .surroundingTextAndWindowTitleWithheld
        case (true, false): .surroundingTextWithheld
        case (false, true): .windowTitleWithheld
        case (false, false): nil
        }
    }
}
