/// The Pre-checks from "Choose paste lifecycle, cancellation and clipboard preservation": refuses a Paste Attempt
/// before anything leaves the machine when the Target is a secure field, or the Active Item is concealed or
/// holds a suspected secret (no editable Target is refused earlier, by the coordinator). The rules found anywhere in
/// a text also screen the surrounding text and the window title of the Target Context before it is sent; the
/// whole-text Opaque Token refuses only the Active Item.
public struct LocalPreChecks: PreCheck {
    private let itemRules: SuspectedSecretRules
    private let contextRules: SuspectedSecretRules

    public init(itemRules: SuspectedSecretRules = .standard, contextRules: SuspectedSecretRules = .anywhere) {
        self.itemRules = itemRules
        self.contextRules = contextRules
    }

    public func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal? {
        if target.isSecureField { return .secureField }
        if item.isConcealed || itemRules.firstMatch(in: item.text) != nil { return .suspectedSecret }
        return nil
    }

    public func screenedContext(of target: BoundTarget) -> ScreenedTargetContext {
        let context = target.context
        let withholdsSurroundingText = contextRules.firstMatch(in: context.surroundingText) != nil
        let withholdsWindowTitle = context.windowTitle.map { contextRules.firstMatch(in: $0) != nil } ?? false
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
