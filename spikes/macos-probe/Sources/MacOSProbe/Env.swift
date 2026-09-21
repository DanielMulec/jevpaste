import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum ProbeIdentity {
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "com.jevpaste.macos-probe.unbundled" }
    static var bundlePath: String { Bundle.main.bundlePath }
    static var isBundled: Bool { Bundle.main.bundleIdentifier != nil }
}

enum Env {
    static func report() {
        let info = ProcessInfo.processInfo
        Log.line("ENV os=\(info.operatingSystemVersionString) host=\(info.hostName)")
        Log.line("ENV bundleID=\(ProbeIdentity.bundleID) bundled=\(ProbeIdentity.isBundled)")
        Log.line("ENV bundlePath=\(ProbeIdentity.bundlePath)")
        Log.line("ENV executable=\(Bundle.main.executablePath ?? "nil")")
        Log.line("ENV activationPolicy=\(NSApp.activationPolicy().rawValue) pid=\(info.processIdentifier)")
        permissions()
        pasteboardPrivacy()
    }

    static func permissions() {
        Log.line("PERM AXIsProcessTrusted=\(AXIsProcessTrusted())")
        Log.line("PERM CGPreflightPostEventAccess=\(CGPreflightPostEventAccess()) "
                 + "(needed to synthesize Cmd+V)")
        Log.line("PERM CGPreflightListenEventAccess=\(CGPreflightListenEventAccess()) "
                 + "(Input Monitoring; needed only for a listening CGEventTap)")
        Log.line("PERM IsSecureEventInputEnabled=\(IsSecureEventInputEnabled()) (global, any process)")
    }

    /// Shows the Accessibility prompt. Requires Daniel to click Allow in System Settings.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.line("PERM requested Accessibility — AXIsProcessTrustedWithOptions=\(trusted) "
                 + "(false here is normal; the grant applies after the app is re-launched)")
    }

    static func requestPostEvent() {
        let granted = CGRequestPostEventAccess()
        Log.line("PERM CGRequestPostEventAccess=\(granted)")
    }

    static func requestListenEvent() {
        let granted = CGRequestListenEventAccess()
        Log.line("PERM CGRequestListenEventAccess=\(granted) (Input Monitoring)")
    }

    // MARK: - Pasteboard privacy (macOS 15.4+)

    static func pasteboardPrivacy() {
        if #available(macOS 15.4, *) {
            let behavior = NSPasteboard.general.accessBehavior
            let name: String
            switch behavior {
            case .default: name = "default(ask for the general pasteboard, per header)"
            case .ask: name = "ask"
            case .alwaysAllow: name = "alwaysAllow"
            case .alwaysDeny: name = "alwaysDeny"
            @unknown default: name = "unknown(\(behavior.rawValue))"
            }
            Log.line("PASTEBOARD accessBehavior=\(name) raw=\(behavior.rawValue)")
        } else {
            Log.line("PASTEBOARD accessBehavior unavailable (<15.4)")
        }
    }

    /// The Swift overlay refines the detection patterns into key paths on `DetectedValues`,
    /// so we keep our own name table to log which pattern matched without logging any value.
    @available(macOS 15.4, *)
    static var patternNames: [(PartialKeyPath<NSPasteboard.DetectedValues>, String)] {
        [(\.probableWebURL, "probableWebURL"),
         (\.emailAddresses, "emailAddresses"),
         (\.number, "number"),
         (\.links, "links")]
    }

    @available(macOS 15.4, *)
    static func name(_ keyPath: PartialKeyPath<NSPasteboard.DetectedValues>) -> String {
        patternNames.first { $0.0 == keyPath }?.1 ?? "unnamed"
    }

    /// Test 1 from the research §5 table: which access kinds trigger the privacy alert.
    static func accessLadder() {
        Log.line("LADDER step 1: changeCount only (no content)")
        let (count, countMs) = Clock.measure { Clipboard.changeCount() }
        Log.line("LADDER changeCount=\(count) ms=\(countMs) — watch for a system alert now")

        Log.line("LADDER step 2: types only (metadata, no data call)")
        let (types, typesMs) = Clock.measure { Clipboard.itemTypesOnly() }
        Log.line("LADDER types=\(types.flatMap { $0 }.joined(separator: ",")) ms=\(typesMs)")

        Log.line("LADDER step 3: detectedMetadata (contentType only — the most metadata-ish read)")
        if #available(macOS 15.4, *) {
            let began = Date()
            Task { @MainActor in
                do {
                    let metadata = try await NSPasteboard.general.detectedMetadata(for: [\.contentType])
                    let ms = (Date().timeIntervalSince(began) * 1000).rounded()
                    Log.line("LADDER detectedMetadata contentType=\(metadata.contentType?.identifier ?? "nil") ms=\(ms)")
                } catch {
                    Log.line("LADDER detectedMetadata error=\(error.localizedDescription)")
                }
            }
        }

        Log.line("LADDER step 4: detectPatterns (documented NOT to notify)")
        if #available(macOS 15.4, *) {
            let patterns = Set(patternNames.map { $0.0 })
            let began = Date()
            Task { @MainActor in
                do {
                    let found = try await NSPasteboard.general.detectedPatterns(for: patterns)
                    let ms = (Date().timeIntervalSince(began) * 1000).rounded()
                    Log.line("LADDER detectedPatterns=\(found.map { Env.name($0) }.sorted().joined(separator: ",")) ms=\(ms)")
                } catch {
                    Log.line("LADDER detectedPatterns error=\(error.localizedDescription)")
                }
            }
        }

        Log.line("LADDER step 5: full content read (string + data)")
        let snapshot = Clipboard.snapshot()
        Clipboard.describe(snapshot, label: "LADDER contentRead")
        Log.line("LADDER done — report whether ANY system alert appeared, and at which step")
    }

    /// detectedValues is documented to notify, unlike detectedPatterns.
    static func detectValues() {
        guard #available(macOS 15.4, *) else { return }
        let patterns = Set(patternNames.map { $0.0 })
        let began = Date()
        Task { @MainActor in
            do {
                let values = try await NSPasteboard.general.detectedValues(for: patterns)
                let ms = (Date().timeIntervalSince(began) * 1000).rounded()
                // Pattern names only. The detected values themselves are user content and are never logged.
                let matched = values.patterns.map { Env.name($0) }.sorted().joined(separator: ",")
                Log.line("DETECTVALUES matchedPatterns=\(matched) count=\(values.patterns.count) "
                         + "ms=\(ms) — did an alert appear?")
            } catch {
                Log.line("DETECTVALUES error=\(error.localizedDescription)")
            }
        }
    }

    /// Measures repeated AX focus+identify reads to compare against the 150 ms feedback target.
    static func axTimings(iterations: Int) {
        var lookup: [Double] = []
        var roleRead: [Double] = []
        var valueRead: [Double] = []
        for _ in 0..<iterations {
            let focus = AXProbe.focused()
            lookup.append(focus.lookupMs)
            guard let element = focus.element else { continue }
            let (_, roleMs) = Clock.measure { AXProbe.string(element, kAXRoleAttribute as String) }
            roleRead.append(roleMs)
            let (_, valueMs) = Clock.measure { AXProbe.valueSummary(element) }
            valueRead.append(valueMs)
            usleep(20_000)
        }
        func render(_ name: String, _ samples: [Double]) {
            let stats = Clock.percentiles(samples)
            Log.line("TIMING \(name) n=\(samples.count) p50=\(stats.p50)ms p95=\(stats.p95)ms max=\(stats.max)ms")
        }
        render("focusedElementLookup", lookup)
        render("roleRead", roleRead)
        render("valueSummaryRead", valueRead)
    }
}
