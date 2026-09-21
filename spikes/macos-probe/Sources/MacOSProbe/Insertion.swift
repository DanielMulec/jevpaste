import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Insertion experiments. All inserted text is synthetic and generated here.
enum Insertion {
    private static var sequence = 0

    static func syntheticPayload(_ tag: String) -> String {
        sequence += 1
        return "JEVPROBE-\(tag)-\(sequence)"
    }

    // MARK: - Path A: pasteboard swap + synthesized Cmd+V + restore

    struct PasteOutcome {
        var payload: String
        var ownedChangeCount: Int
        var countAfterPaste: Int
        var restoredIntact: Bool
        var restoreFailures: [String]
        var totalMs: Double
    }

    @discardableResult
    static func pasteSwap(restoreDelayMs: Double, label: String = "INSERT-A") -> PasteOutcome {
        let payload = syntheticPayload("A")
        Log.line("\(label) begin restoreDelay=\(restoreDelayMs)ms postEventAccess=\(CGPreflightPostEventAccess())")

        // Objective before/after check on the target itself, so "did it insert" is not eyeballed.
        let targetFocus = AXProbe.focused()
        let valueBefore = targetFocus.element.map { AXProbe.valueSummary($0) } ?? "no-element"
        Log.line("\(label) target=\(targetFocus.bundleID) valueBefore \(valueBefore)")

        let before = Clipboard.snapshot()
        Clipboard.describe(before, label: "\(label) original")

        let start = DispatchTime.now().uptimeNanoseconds
        let owned = Clipboard.writeSynthetic(payload)
        Log.synthetic("\(label) wrote payload=\(payload) ownedChangeCount=\(owned) actualCount=\(Clipboard.changeCount())")

        let (_, postMs) = Clock.measure { postCommandV() }
        Log.line("\(label) posted Cmd+V in \(postMs)ms")

        Thread.sleep(forTimeInterval: restoreDelayMs / 1000.0)

        let countAfterPaste = Clipboard.changeCount()
        if countAfterPaste > owned + 1 {
            Log.fail("\(label) somebody wrote to the pasteboard during our window "
                     + "(ours=\(owned + 1) now=\(countAfterPaste)) — a real client must NOT restore here")
        }
        // Path A deliberately restores even when the guard trips, so the before/after fingerprint
        // comparison below always runs. The guard is OBSERVED here; `race` tests ENFORCING it.
        let (_, failures) = Clipboard.restore(before)
        let totalMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0

        let after = Clipboard.snapshot()
        Clipboard.describe(after, label: "\(label) restored")
        let intact = after.fingerprint == before.fingerprint
        Log.line("\(label) restoredIntact=\(intact) typesAndHashesMatch=\(intact) "
                 + "restoreFailures=\(failures.isEmpty ? "none" : failures.joined(separator: ","))")
        Log.line("\(label) changeCount original=\(before.changeCount) afterRestore=\(after.changeCount) "
                 + "(a restore always advances the count — content equality is what matters)")
        Log.line("\(label) totalMs=\((totalMs * 100).rounded() / 100)")

        let afterFocus = AXProbe.focused()
        let valueAfter = afterFocus.element.map { AXProbe.valueSummary($0) } ?? "no-element"
        Log.line("\(label) valueAfter \(valueAfter) (compare chars/sha with valueBefore to confirm insertion; "
                 + "payload is \(payload.count) chars)")

        return PasteOutcome(payload: payload, ownedChangeCount: owned, countAfterPaste: countAfterPaste,
                            restoredIntact: intact, restoreFailures: failures,
                            totalMs: (totalMs * 100).rounded() / 100)
    }

    static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Path B: AX setters

    static func axInsert(label: String = "INSERT-B") {
        let payload = syntheticPayload("B")
        let focus = AXProbe.focused()
        guard let element = focus.element else {
            Log.fail("\(label) no focused element (\(focus.error.probeName)) — AX insertion impossible")
            return
        }
        let role = AXProbe.string(element, kAXRoleAttribute as String) ?? "nil"
        let subrole = AXProbe.string(element, kAXSubroleAttribute as String) ?? "nil"
        let secure = AXProbe.looksSecure(element: element, role: role, subrole: subrole)
        guard secure.verdict == "no" else {
            Log.fail("\(label) refusing to write into a suspected secure target (\(secure.verdict))")
            return
        }

        Log.line("\(label) target=\(focus.bundleID) role=\(role) subrole=\(subrole) "
                 + "settable(AXSelectedText)=\(AXProbe.settable(element, kAXSelectedTextAttribute as String)) "
                 + "settable(AXValue)=\(AXProbe.settable(element, kAXValueAttribute as String))")

        let (selectedError, selectedMs) = AXProbe.setSelectedText(element, payload)
        Log.synthetic("\(label) AXSelectedText <- \(payload) result=\(selectedError.probeName) in \(selectedMs)ms")

        if selectedError != .success {
            let existing = AXProbe.string(element, kAXValueAttribute as String) ?? ""
            let (valueError, valueMs) = AXProbe.setValue(element, existing + payload)
            Log.synthetic("\(label) AXValue <- existing+\(payload) result=\(valueError.probeName) in \(valueMs)ms")
        }
        Log.line("\(label) VERIFY VISUALLY: did the synthetic marker appear, and does the app's own state agree "
                 + "(e.g. does a Send button enable, does React see the change)?")
    }

    // MARK: - Race: concurrent copy inside the swap window

    static func raceTest(windowMs: Double) {
        Log.line("RACE begin — simulating another app copying \(windowMs / 2)ms into our swap window")
        let before = Clipboard.snapshot()
        let owned = Clipboard.writeSynthetic(syntheticPayload("RACE-OURS"))
        let ourCount = Clipboard.changeCount()

        DispatchQueue.global().asyncAfter(deadline: .now() + windowMs / 2000.0) {
            let item = NSPasteboardItem()
            item.setString("JEVPROBE-FOREIGN-COPY", forType: .string)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([item])
            Log.synthetic("RACE foreign copy written, changeCount=\(NSPasteboard.general.changeCount)")
        }

        Thread.sleep(forTimeInterval: windowMs / 1000.0)
        let now = Clipboard.changeCount()
        let stillOurs = now == ourCount
        Log.line("RACE ourWriteCount=\(ourCount) (clearContents returned \(owned)) nowCount=\(now) stillOurs=\(stillOurs)")
        if stillOurs {
            Clipboard.restore(before)
            Log.line("RACE guard says safe → restored original")
        } else {
            Log.fail("RACE guard DETECTED a foreign write → a real client must abandon the restore "
                     + "(restoring would destroy what the user just copied). Not restoring.")
        }
        Clipboard.describe(Clipboard.snapshot(), label: "RACE final")
    }

    // MARK: - Focus drift between hotkey and insertion

    static func focusDrift(delayMs: Double) {
        let first = AXProbe.focused()
        Log.line("DRIFT t0 frontmost=\(first.bundleID) element=\(first.element == nil ? "nil" : "ok")")
        Thread.sleep(forTimeInterval: delayMs / 1000.0)
        let second = AXProbe.focused()
        var sameElement = "n/a"
        if let a = first.element, let b = second.element {
            sameElement = CFEqual(a, b) ? "same" : "DIFFERENT"
        }
        let sameApp = first.bundleID == second.bundleID
        Log.line("DRIFT t0+\(delayMs)ms frontmost=\(second.bundleID) sameApp=\(sameApp) focusedElement=\(sameElement)")
        if !sameApp || sameElement == "DIFFERENT" {
            Log.fail("DRIFT focus moved during the simulated round trip — a real client must capture the target "
                     + "at hotkey time and re-verify before inserting")
        }
    }
}
