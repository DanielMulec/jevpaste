/// The local rules that refuse a Paste Attempt before anything leaves the machine: secure fields and
/// concealed or suspected-secret Active Items.
///
/// The rules arrive with the Pre-check slice; tests supply stubs.
public protocol PreCheck: Sendable {
    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal?
}
