/// The Pre-checks from "Choose paste lifecycle, cancellation and clipboard preservation": refuses a Paste Attempt
/// before anything leaves the machine when the Target is a secure field, or the Active Item is concealed or
/// holds a suspected secret. (No editable Target is refused earlier, by the coordinator.)
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
}
