import SmartPasteCore

/// Copy Capture reports Active Item changes to one observer; this is it, passing each change on to every part of the
/// shell that shows the Active Item — the History Search panel and Settings' Full History.
@MainActor
final class ActiveItemChanges {
    private var listeners: [@MainActor (ActiveItemChange) -> Void] = []

    /// Copy Capture holds this for as long as it lives (strongly, without a cycle: this never holds the capture), so
    /// no one else has to.
    init(capture: CopyCapture) {
        capture.observeActiveItemChanges { change in
            for listener in self.listeners {
                listener(change)
            }
        }
    }

    func observe(_ listener: @escaping @MainActor (ActiveItemChange) -> Void) {
        listeners.append(listener)
    }
}
