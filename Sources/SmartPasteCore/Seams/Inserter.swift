/// Makes the frontmost app paste the clipboard into the Bound Target. Insert only; never sends or executes.
///
/// The Paste Attempt swaps the clipboard around this call. The real adapter lives in `MacInterop`
/// (synthetic ⌘V; never Return, never a key-sequence insertion); tests supply an in-memory fake.
@MainActor
public protocol Inserter {
    func postPasteKeystroke()
}
