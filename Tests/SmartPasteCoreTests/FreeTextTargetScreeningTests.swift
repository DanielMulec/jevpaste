import SmartPasteCore
import Testing

/// The window title joins the Target Context sent to Jev and is screened by the same suspected-secret rules as the
/// surrounding text; the app name, like the labels, is sent as read.
struct FreeTextTargetScreeningTests {
    private let preChecks = LocalPreChecks()
    private static let secret = "postgres://deploy:hunter2@db.example.org/app"
    private static let ordinaryWindow = "you: can you summarise this contact?"

    private static func context(surroundingText: String, windowTitle: String?) -> TargetContext {
        TargetContext(
            fieldLabel: "Message", surroundingText: surroundingText, appName: "Ghostty", windowTitle: windowTitle
        )
    }

    private func screened(surroundingText: String, windowTitle: String?) -> ScreenedTargetContext {
        preChecks.screenedContext(
            of: BoundTarget(
                identity: TargetIdentity(processIdentifier: 7, elementToken: 1),
                context: Self.context(surroundingText: surroundingText, windowTitle: windowTitle),
                isSecureField: false
            )
        )
    }

    @Test func anOrdinaryWindowTitleAndTheAppNameAreSentUnchanged() {
        let screened = screened(surroundingText: Self.ordinaryWindow, windowTitle: "psql — deploy")

        #expect(screened.context == Self.context(surroundingText: Self.ordinaryWindow, windowTitle: "psql — deploy"))
        #expect(screened.note == nil)
    }

    @Test func aWindowTitleWithASuspectedSecretIsWithheldAndNoted() {
        let screened = screened(surroundingText: Self.ordinaryWindow, windowTitle: "psql " + Self.secret)

        #expect(screened.context == Self.context(surroundingText: Self.ordinaryWindow, windowTitle: nil))
        #expect(screened.note == .windowTitleWithheld)
    }

    @Test func secretsInBothAreWithheldUnderOneNote() {
        let screened = screened(surroundingText: "ops: " + Self.secret, windowTitle: "psql " + Self.secret)

        #expect(screened.context == Self.context(surroundingText: "", windowTitle: nil))
        #expect(screened.note == .surroundingTextAndWindowTitleWithheld)
    }

    @Test func surroundingTextWithASecretKeepsTheWindowTitleAndTheAppName() {
        let screened = screened(surroundingText: "ops: " + Self.secret, windowTitle: "Deploy chat")

        #expect(screened.context == Self.context(surroundingText: "", windowTitle: "Deploy chat"))
        #expect(screened.note == .surroundingTextWithheld)
    }
}
