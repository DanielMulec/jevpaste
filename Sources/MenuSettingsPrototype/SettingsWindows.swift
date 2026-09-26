// PROTOTYPE — menu-settings, never merged
import AppKit

@MainActor
final class SettingsWindows {
    func open(_ section: SettingsSection) { NSLog("[proto] settings %@", String(describing: section)) }
    func stateChanged() {}
}
