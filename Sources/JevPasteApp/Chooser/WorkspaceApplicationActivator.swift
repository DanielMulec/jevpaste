import AppKit

/// The `ApplicationActivator` in the app: `NSRunningApplication` activation and `NSWorkspace`'s frontmost app.
@MainActor
struct WorkspaceApplicationActivator: ApplicationActivator {
    var frontmostProcessIdentifier: Int32? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func activate(processIdentifier: Int32) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: processIdentifier),
            !application.isTerminated
        else { return false }
        // Cooperative activation (macOS 14): yield first, in case the chooser made jevpaste the active app.
        NSApp.yieldActivation(to: application)
        // `false` only means macOS declined the request; the frontmost poll decides, bounded.
        _ = application.activate()
        return true
    }
}
