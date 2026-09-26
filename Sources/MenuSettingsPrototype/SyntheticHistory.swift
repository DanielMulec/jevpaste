// PROTOTYPE — menu-settings, never merged
// Invented data only: no names, addresses or numbers from any real person or machine.

enum SyntheticHistory {
    private static let log = (1...30).map { index in
        let level = index % 7 == 0 ? "WARN" : (index == 23 ? "ERROR" : "INFO")
        return "2026-09-21 14:0\(index % 10):\(10 + index) \(level) build step \(index)/30 — "
            + (index == 23 ? "linker failed: undefined symbol _protoExample" : "ok in \(index * 13) ms")
    }.joined(separator: "\n")

    private static let entries: [(String, Int, ItemKind)] = [
        ("mara.lindqvist@example.org", 2, .email),
        ("https://example.com/orders/48213/invoice?lang=en", 5, .link),
        ("Mara Lindqvist\nBirkenweg 14\n12345 Nordhausen\nGermany", 9, .address),
        ("+49 30 5550 1234", 14, .phone),
        (log, 21, .log),
        ("Invoice number: INV-2026-0917\nAmount: 184.20 EUR\nDue date: 2026-10-15\nReference: PROTO-7731", 33, .labelled),
        ("let rows = history.search(query).prefix(5)\nmenu.update(rows)", 47, .code),
        ("Thanks for the quick reply — the example build now starts on both machines. I'll send the "
            + "remaining notes tomorrow morning, together with the updated timeline.", 58, .text),
        ("jonas.berglund@example.net", 72, .email),
        ("https://example.org/docs/getting-started#install", 95, .link),
        ("Tomas Kowal\nAm Lindenhof 3\n54321 Westerfeld\nGermany", 130, .address),
        ("+43 1 5550 9876", 160, .phone),
        ("SELECT id, title FROM example_items WHERE archived = 0 ORDER BY created_at DESC;", 190, .code),
        ("Booking code: XK7-PROTO\nGuest: E. Novak\nArrival: 2026-11-02\nNights: 3", 240, .labelled),
        ("orders@example.com", 300, .email),
        ("DE00 0000 0000 0000 0000 00", 360, .text),
        ("The meeting moves to Thursday at 10:00. The agenda stays the same; please bring the example "
            + "figures from last week so we can compare them against the new estimate.", 420, .text),
        ("https://example.com/tracking/1Z999AA10123456784", 500, .link),
        ("{\n  \"name\": \"example\",\n  \"version\": \"0.4.2\",\n  \"private\": true\n}", 600, .code),
        ("support@example.org", 720, .email),
        ("Lea Hartmann\nSeestraße 88\n67890 Oberried\nGermany", 900, .address),
        ("+49 170 5550 4321", 1100, .phone),
        ("Nordhausen", 1300, .text),
        ("Order ID: 48213\nCustomer: Example GmbH\nItems: 3\nTotal: 92.00 EUR", 1500, .labelled),
        ("git switch -c prototype/example && swift run", 1800, .code),
        ("anna.falk@example.net", 2100, .email),
        ("https://example.org/blog/2026/09/release-notes", 2500, .link),
        ("Please find the example contract attached. Sections 3 and 5 changed; everything else is "
            + "identical to the draft from August.", 2900, .text),
        ("2026-10-15", 3300, .text),
        ("+41 44 555 01 23", 3800, .phone),
        ("1Z999AA10123456784", 4400, .text),
        ("billing@example.com", 5000, .email),
        ("Example GmbH · Musterallee 1 · 10115 Berlin", 5600, .text),
        ("func greet(_ name: String) -> String {\n    \"Hello, \\(name)\"\n}", 6300, .code),
        ("https://example.com/account/settings", 7000, .link),
        ("Room: 4.12\nFloor: 4\nBuilding: Example Campus West", 8000, .labelled),
        ("See you at the example station at 18:30.", 9000, .text),
        ("noah.weber@example.org", 10200, .email),
        ("ex-4471-proto", 11500, .text),
        ("Thank you!", 12900, .text),
    ]

    static let items: [ClipItem] = entries.enumerated().map { index, entry in
        ClipItem(id: index + 1, text: entry.0, ageMinutes: entry.1, kind: entry.2)
    }
}
