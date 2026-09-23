import AppKit

/// Entry point of the jevpaste menu-bar app: an accessory `NSApplication` with one status item, or the adapter
/// probe when launched with `--probe <log-path>`.
@main
@MainActor
enum MenuBarApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = makeDelegate(arguments: CommandLine.arguments)
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    private static func makeDelegate(arguments: [String]) -> any NSApplicationDelegate {
        if let flag = arguments.firstIndex(of: "--probe"), arguments.indices.contains(flag + 1) {
            return AdapterProbe(logPath: arguments[flag + 1])
        }
        return MenuBarDelegate()
    }
}
