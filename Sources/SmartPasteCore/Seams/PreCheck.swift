/// The local rules applied before anything leaves the machine: refusals for secure fields and concealed or
/// suspected-secret Active Items, and the screening of the Target Context that is sent to Jev.
///
/// The Core adapter is `LocalPreChecks`; tests supply stubs.
public protocol PreCheck: Sendable {
    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal?
    /// The Target Context to send for `target`: a surrounding-text window holding a suspected secret is dropped
    /// and noted. Never a refusal.
    func screenedContext(of target: BoundTarget) -> ScreenedTargetContext
}
