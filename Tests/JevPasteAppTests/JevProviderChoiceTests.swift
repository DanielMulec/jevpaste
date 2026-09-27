import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The Jev Provider chosen in Settings survives relaunches; nothing chosen, an unknown value or a provider that is
/// not built yet reads as the Vercel AI Gateway.
@MainActor
struct JevProviderChoiceTests {
    private let scratch = ScratchDefaults()

    @Test func nothingChosenIsTheVercelAIGateway() {
        #expect(JevProviderChoice(defaults: scratch.defaults).provider == .vercelAIGateway)
    }

    @Test func theChoiceIsReadBackByTheNextLaunch() {
        JevProviderChoice(defaults: scratch.defaults).choose(.vercelAIGateway)

        #expect(JevProviderChoice(defaults: scratch.defaults).provider == .vercelAIGateway)
        #expect(scratch.defaults.string(forKey: "jevProvider") == "vercelAIGateway")
    }

    @Test(arguments: ["typesafeDirect", "someFutureProvider"])
    func aProviderThatIsNotBuiltReadsAsTheDefault(stored: String) {
        scratch.defaults.set(stored, forKey: "jevProvider")

        #expect(JevProviderChoice(defaults: scratch.defaults).provider == .vercelAIGateway)
    }
}
