import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The Jev Provider chosen in Settings survives relaunches; nothing chosen or an unknown value reads as the Vercel AI
/// Gateway.
@MainActor
struct JevProviderChoiceTests {
    private let scratch = ScratchDefaults()

    @Test func nothingChosenIsTheVercelAIGateway() {
        #expect(JevProviderChoice(defaults: scratch.defaults).provider == .vercelAIGateway)
    }

    @Test(arguments: [(JevProvider.vercelAIGateway, "vercelAIGateway"), (.typesafeDirect, "typesafeDirect")])
    func theChoiceIsReadBackByTheNextLaunch(provider: JevProvider, stored: String) {
        JevProviderChoice(defaults: scratch.defaults).choose(provider)

        #expect(JevProviderChoice(defaults: scratch.defaults).provider == provider)
        #expect(scratch.defaults.string(forKey: "jevProvider") == stored)
    }

    @Test(arguments: ["someFutureProvider", ""])
    func anUnknownValueReadsAsTheDefault(stored: String) {
        scratch.defaults.set(stored, forKey: "jevProvider")

        #expect(JevProviderChoice(defaults: scratch.defaults).provider == .vercelAIGateway)
    }
}
