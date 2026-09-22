import SmartPasteCore
import Testing

@testable import MacInterop

@MainActor
struct FocusedTargetResolverTests {
    private let source = FakeFocusSource()
    private var resolver: FocusedTargetResolver<FakeFocusSource> { FocusedTargetResolver(source: source) }

    @Test func nothingFocusedResolvesToNoTarget() {
        #expect(resolver.resolveFocusedTarget() == nil)
    }

    @Test func focusedTextFieldResolvesToABoundTargetInItsProcess() {
        source.focus(FakeNode("AXTextField"), processIdentifier: 7)

        let target = resolver.resolveFocusedTarget()

        #expect(target?.identity.processIdentifier == 7)
        #expect(target?.isSecureField == false)
    }

    @Test(arguments: ["AXTextField", "AXTextArea", "AXComboBox"])
    func textRolesAreEditable(role: String) {
        source.focus(FakeNode(role))
        #expect(resolver.resolveFocusedTarget() != nil)
    }

    @Test func groupWithASettableSelectionIsEditable() {
        let contentEditable = FakeNode("AXGroup")
        contentEditable.isSelectedTextRangeSettable = true
        source.focus(contentEditable)

        #expect(resolver.resolveFocusedTarget() != nil)
    }

    @Test func nonEditableFocusResolvesToNoTarget() {
        source.focus(FakeNode("AXGroup", [.subrole: "iOSContentGroup"]))
        #expect(resolver.resolveFocusedTarget() == nil)
    }

    @Test func secureTextFieldIsASecureTargetWithoutContext() {
        let parent = FakeNode("AXGroup", [.title: "Sign in"])
        let password = FakeNode("AXTextField", [.subrole: "AXSecureTextField", .title: "Password", .value: "hunter2"])
        parent.adopt(password)
        source.focus(password)

        let target = resolver.resolveFocusedTarget()

        #expect(target?.isSecureField == true)
        #expect(target?.context == TargetContext())
    }

    @Test func secureEventInputMakesAnyTargetSecure() {
        source.focus(FakeNode("AXTextArea"))
        source.isSecureEventInputEnabled = true

        #expect(resolver.resolveFocusedTarget()?.isSecureField == true)
    }

    @Test func boundTargetIsStillFocusedWhileTheSameElementInTheSameProcessHasFocus() {
        let field = FakeNode("AXTextField")
        source.focus(field, processIdentifier: 7)
        let resolver = resolver
        let identity = resolver.resolveFocusedTarget()?.identity

        #expect(identity.map(resolver.isStillFocused) == true)
    }

    @Test func boundTargetIsNoLongerFocusedWhenAnotherElementHasFocus() {
        source.focus(FakeNode("AXTextField"), processIdentifier: 7)
        let resolver = resolver
        let identity = resolver.resolveFocusedTarget()?.identity

        source.focus(FakeNode("AXTextField"), processIdentifier: 7)

        #expect(identity.map(resolver.isStillFocused) == false)
    }

    @Test func boundTargetIsNoLongerFocusedWhenAnotherProcessHasFocus() {
        let field = FakeNode("AXTextField")
        source.focus(field, processIdentifier: 7)
        let resolver = resolver
        let identity = resolver.resolveFocusedTarget()?.identity

        source.focus(field, processIdentifier: 8)

        #expect(identity.map(resolver.isStillFocused) == false)
    }

    @Test func boundTargetIsNoLongerFocusedWhenNothingHasFocus() {
        source.focus(FakeNode("AXTextField"))
        let resolver = resolver
        let identity = resolver.resolveFocusedTarget()?.identity

        source.focused = nil

        #expect(identity.map(resolver.isStillFocused) == false)
    }

    @Test func earlierBoundTargetIsNotReverifiedAfterANewerOneWasBound() {
        let field = FakeNode("AXTextField")
        source.focus(field)
        let resolver = resolver
        let earlier = resolver.resolveFocusedTarget()?.identity
        let later = resolver.resolveFocusedTarget()?.identity

        #expect(earlier != later)
        #expect(earlier.map(resolver.isStillFocused) == false)
        #expect(later.map(resolver.isStillFocused) == true)
    }

    @Test func identityThisResolverNeverMintedIsNotFocused() {
        source.focus(FakeNode("AXTextField"), processIdentifier: 7)

        #expect(resolver.isStillFocused(TargetIdentity(processIdentifier: 7, elementToken: 99)) == false)
    }
}
