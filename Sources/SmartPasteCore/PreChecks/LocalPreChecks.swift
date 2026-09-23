/// The Pre-checks from "Choose paste lifecycle, cancellation and clipboard preservation": refuses a Paste Attempt
/// before anything leaves the machine when the Target is a secure field, or the Active Item is concealed or
/// holds a suspected secret (no editable Target is refused earlier, by the coordinator). The same secret rules
/// screen the surrounding text of the Target Context before it is sent.
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
        guard secretRules.firstMatch(in: context.surroundingText) != nil else {
            return ScreenedTargetContext(context: context, note: nil)
        }
        let withoutSurroundingText = TargetContext(
            fieldLabel: context.fieldLabel, placeholder: context.placeholder, sectionHeading: context.sectionHeading,
            siblingFieldLabels: context.siblingFieldLabels
        )
        return ScreenedTargetContext(context: withoutSurroundingText, note: .surroundingTextWithheld)
    }
}
