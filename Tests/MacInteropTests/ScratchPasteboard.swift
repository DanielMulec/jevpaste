import AppKit

/// A uniquely named pasteboard for one test, released from the pasteboard server when the test ends, so tests
/// never touch the general pasteboard.
final class ScratchPasteboard {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("jevpaste-test-\(UUID().uuidString)"))

    deinit {
        pasteboard.releaseGlobally()
    }
}
