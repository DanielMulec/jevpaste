import AppKit

/// Entry point of the jevpaste menu-bar app: an accessory `NSApplication` with one status item.
@main
@MainActor
enum MenuBarApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = MenuBarDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
