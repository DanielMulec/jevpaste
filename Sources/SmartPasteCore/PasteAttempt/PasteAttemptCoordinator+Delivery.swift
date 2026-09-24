/// The uninterruptible delivery step, shared by both Smart Paste paths: write the text to the clipboard, post ⌘V,
/// wait the fixed Restore Window, restore the original clipboard byte for byte.
extension PasteAttemptCoordinator {
    /// Fixed: 20 ms pasted the previous clipboard on two engines, 120 ms was clean on all five targets.
    static let restoreDelay = Duration.milliseconds(120)

    /// Delivers `text`: a Paste Result that `RunningAttempt.accepts(_:offeredAmong:)` already validated, or a
    /// Direct Paste text. The Bound Target is re-verified first on both paths.
    func deliver(_ text: String) {
        guard let attempt else { return }
        stopClocks()
        phase = .delivering
        guard ports.targetResolver.isStillFocused(attempt.target.identity) else {
            return finish(.failed(.targetChanged))
        }
        ports.presenter.showDelivering()
        let original = ports.clipboard.snapshot()
        let ownWrite = ports.clipboard.write(text)
        capture.markOwnWrite(ownWrite)
        ports.inserter.postPasteKeystroke()
        schedule(after: Self.restoreDelay) { coordinator in
            coordinator.endRestoreWindow(restoring: original, unlessChangedSince: ownWrite)
        }
    }

    /// Restores the original clipboard, unless someone copied during the Restore Window: the paste has landed
    /// and the new copy wins.
    private func endRestoreWindow(restoring original: ClipboardSnapshot, unlessChangedSince ownWrite: Int) {
        guard ports.clipboard.changeCount == ownWrite else { return finish(.insertedWithoutRestore) }
        capture.markOwnWrite(ports.clipboard.restore(original))
        finish(.inserted)
    }
}
