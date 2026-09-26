import SmartPasteCore
import Testing

@testable import MacInterop

/// The Target Context names the app the Target belongs to and the title of its window, so Jev can judge whether
/// the Target is a Free-text Target. The bundle id is never part of it.
@MainActor
struct FreeTextTargetContextTests {
    private let source = FakeFocusSource()
    private var resolver: FocusedTargetResolver<FakeFocusSource> { FocusedTargetResolver(source: source) }

    private func composer(inWindowTitled title: String?) -> FakeNode {
        let composer = FakeNode("AXTextArea")
        composer.window = FakeNode("AXWindow", title.map { [.title: $0] } ?? [:])
        return composer
    }

    @Test func theAppNameAndTheWindowTitleOfTheFocusedElementAreRead() {
        source.focus(composer(inWindowTitled: "New chat"), applicationName: "ChatGPT")

        let context = resolver.resolveFocusedTarget().boundTarget?.context

        #expect(context?.appName == "ChatGPT")
        #expect(context?.windowTitle == "New chat")
    }

    @Test func aTargetWithoutAWindowOrAnUntitledWindowHasNoWindowTitle() {
        source.focus(FakeNode("AXTextArea"))
        #expect(resolver.resolveFocusedTarget().boundTarget?.context.windowTitle == nil)

        source.focus(composer(inWindowTitled: nil))
        #expect(resolver.resolveFocusedTarget().boundTarget?.context.windowTitle == nil)

        source.focus(composer(inWindowTitled: ""))
        #expect(resolver.resolveFocusedTarget().boundTarget?.context.windowTitle == nil)
    }

    /// The focused element carries no bundle identifier at all, so there is nothing to fall back to.
    @Test func anAppWithoutALocalizedNameHasNoAppName() {
        source.focus(composer(inWindowTitled: "Inbox"), applicationName: nil)

        #expect(resolver.resolveFocusedTarget().boundTarget?.context.appName == nil)
    }

    @Test func aSecureFieldSendsNeitherAppNameNorWindowTitle() {
        let password = FakeNode("AXTextField", [.subrole: "AXSecureTextField"])
        password.window = FakeNode("AXWindow", [.title: "Sign in"])
        source.focus(password, applicationName: "Safari")

        #expect(resolver.resolveFocusedTarget().boundTarget?.context == TargetContext())
    }
}
