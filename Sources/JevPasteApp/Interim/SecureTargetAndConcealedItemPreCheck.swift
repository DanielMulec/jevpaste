import SmartPasteCore

/// Interim `PreCheck` for the tracer bullet: refuses secure Targets and concealed Active Items, allows the rest.
/// Replaced by the rules of "Implement Pre-check rules" (suspected-secret detection included).
struct SecureTargetAndConcealedItemPreCheck: PreCheck {
    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal? {
        if target.isSecureField { return .secureField }
        if item.isConcealed { return .suspectedSecret }
        return nil
    }
}
