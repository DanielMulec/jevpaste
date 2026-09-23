import AppKit

/// A uniquely named pasteboard for one test, released from the pasteboard server when the test ends, so tests
/// never touch the general pasteboard.
final class ScratchPasteboard {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("jevpaste-test-\(UUID().uuidString)"))

    deinit {
        pasteboard.releaseGlobally()
    }

    /// Copies like another app would, through the legacy declare-then-set API: it also accepts pre-UTI marker
    /// names such as "Pasteboard generator type", which `NSPasteboardItem` rejects.
    func copyLikeAnotherApp(_ bytesByType: [String: Data]) {
        pasteboard.declareTypes(bytesByType.keys.map { NSPasteboard.PasteboardType($0) }, owner: nil)
        for (type, bytes) in bytesByType {
            pasteboard.setData(bytes, forType: NSPasteboard.PasteboardType(type))
        }
    }
}
