import SmartPasteCore

/// The `Hotkey` adapter: ⌘⇧V system-wide, reported when the shortcut is **released**.
///
/// Starting a Paste Attempt on release means no key of the shortcut is still held when the attempt later posts
/// its ⌘V: Chrome drops a synthetic ⌘V while ⌘⇧V is physically down (signed probe run). Waiting at delivery
/// instead would open a gap after the Bound Target was re-verified, in which focus could move.
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
