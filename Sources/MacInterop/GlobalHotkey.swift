import SmartPasteCore

/// The `Hotkey` adapter: ⌘⇧V system-wide, reported on Carbon's hot-key **release**, which comes when V goes up.
///
/// ⌘ and ⇧ may still be held then; the signed re-probe pasted into Chrome with both down, so that is harmless.
/// What Chrome drops is a synthetic ⌘V while V is physically down (signed probe run), and starting the Paste
/// Attempt on V-up avoids it. Waiting at delivery instead would open a gap after the Bound Target was re-verified,
/// in which focus could move.
@MainActor
public final class GlobalHotkey: Hotkey {
    private let registrar: any HotKeyRegistrar
    private var onPress: (@MainActor () -> Void)?

    public convenience init() {
        self.init(registrar: CarbonHotKeyRegistrar())
    }

    init(registrar: any HotKeyRegistrar) {
        self.registrar = registrar
    }

    public func startListening(onPress: @escaping @MainActor () -> Void) {
        let isRegistered = self.onPress != nil
        self.onPress = onPress
        guard !isRegistered else { return }
        registrar.registerCommandShiftV { [weak self] event in
            if event == .released { self?.onPress?() }
        }
    }
}
