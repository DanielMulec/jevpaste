// PROTOTYPE — menu-settings, never merged
import AppKit

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = ProtoAppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { application.run() }
}
