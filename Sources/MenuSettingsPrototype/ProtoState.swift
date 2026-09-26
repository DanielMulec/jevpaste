// PROTOTYPE — menu-settings, never merged
import AppKit

enum ItemKind { case email, link, phone, address, log, text, code, labelled }

struct ClipItem {
    let id: Int
    let text: String
    let ageMinutes: Int
    let kind: ItemKind

    var firstLine: String {
        text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? text
    }
    var lineCount: Int { text.split(separator: "\n", omittingEmptySubsequences: false).count }

    var ageText: String {
        if ageMinutes < 60 { return "\(ageMinutes) min ago" }
        if ageMinutes < 60 * 24 { return "\(ageMinutes / 60) h ago" }
        return "\(ageMinutes / (60 * 24)) d ago"
    }

    var detailText: String {
        lineCount > 1 ? "\(lineCount) lines · \(ageText)" : "\(text.count) chars · \(ageText)"
    }

    var symbolName: String {
        switch kind {
        case .email: "envelope"
        case .link: "link"
        case .phone: "phone"
        case .address: "house"
        case .log: "list.bullet.rectangle"
        case .text: "text.alignleft"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .labelled: "list.dash"
        }
    }
}

enum JevProvider: String, CaseIterable {
    case gateway = "Vercel AI Gateway"
    case typesafe = "Typesafe direct"
}

enum TestResult: Equatable {
    case none, testing, ok
    case failed(String)
}

/// All prototype state, in memory only. Every change notifies the observers so every window shows it.
@MainActor
final class ProtoState {
    static let shared = ProtoState()

    var items: [ClipItem] = SyntheticHistory.items
    var activeID: Int? = SyntheticHistory.items.first?.id
    var menuVariant = "A" { didSet { changed() } }
    var rowStyle = 1 { didSet { changed() } }
    var settingsVariant = 1 { didSet { changed() } }
    var provider: JevProvider = .gateway { didSet { changed() } }
    var keys: [JevProvider: String] = [.gateway: "vck_proto_4f2a9c1e7b0d", .typesafe: ""]
    var testResults: [JevProvider: TestResult] = [:]
    var openAtLogin = true { didSet { changed() } }
    var lastEvent = "launched"
    var query = ""

    private var observers: [() -> Void] = []

    var activeItem: ClipItem? { items.first { $0.id == activeID } }

    func observe(_ block: @escaping () -> Void) { observers.append(block) }

    func changed() { for observer in observers { observer() } }

    func note(_ event: String) {
        lastEvent = event
        NSLog("[proto] %@", event)
        changed()
    }

    func setActive(_ id: Int, via source: String) {
        activeID = id
        note("\(source): Active Item = \"\(activeItem?.firstLine.prefix(40) ?? "")\"")
    }

    func delete(_ id: Int) {
        let line = items.first { $0.id == id }?.firstLine.prefix(30) ?? ""
        items.removeAll { $0.id == id }
        if activeID == id { activeID = nil }
        note("deleted \"\(line)\" — \(items.count) items left")
    }

    func clearHistory() {
        items.removeAll()
        activeID = nil
        note("Clear History — 0 items")
    }

    /// Up to five newest matches and the total number of matches.
    func search(_ query: String) -> (rows: [ClipItem], total: Int) {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return ([], 0) }
        let matches = items.filter { $0.text.localizedCaseInsensitiveContains(needle) }
        return (Array(matches.prefix(5)), matches.count)
    }

    /// The canned "Test": ✓ after 0.8 s, or the error text when the key is empty.
    func test(_ provider: JevProvider) {
        testResults[provider] = .testing
        note("Test \(provider.rawValue)…")
        let key = keys[provider] ?? ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.testResults[provider] = key.isEmpty
                ? .failed("No key entered — paste your \(provider.rawValue) API key first.")
                : .ok
            self.note("Test \(provider.rawValue): \(key.isEmpty ? "error" : "✓")")
        }
    }

    var placeholder: String {
        activeItem.map(\.firstLine) ?? "Search Clipboard History"
    }

    var label: String {
        let active = activeItem.map { "\"\($0.firstLine.prefix(28))\"" } ?? "none"
        return "PROTOTYPE · Menu \(menuVariant) · Rows \(rowStyle) · Settings \(settingsVariant)\n"
            + "Active Item: \(active)\nJev Provider: \(provider.rawValue) · Open at Login: "
            + (openAtLogin ? "on" : "off") + "\nlast: \(lastEvent.prefix(60))"
    }
}
