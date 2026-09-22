import SmartPasteCore
import Testing

/// The same-type alternatives to `chosen` among `texts`, as plain strings.
private func sameTypeTexts(to chosen: String, among texts: [String]) -> [String] {
    StructuralCandidateExtraction()
        .sameTypeAlternatives(to: Candidate(text: chosen), among: texts.map(Candidate.init(text:)))
        .map(\.text)
}

struct CandidateSameTypeTests {
    static let contactCard = [
        "Ada Lovelace", "Email: ada@example.com", "ada@example.com", "press@work.example.co.uk",
        "https://ada.example", "www.analytical.example/engine", "+44 20 7946 0958", "(020) 7946-0000",
        "@ada_lovelace", "@babbage", "London", "10:30",
    ]

    @Test func emailsShareATypeAndIncludeTheChosenOne() {
        #expect(
            sameTypeTexts(to: "press@work.example.co.uk", among: Self.contactCard)
                == ["ada@example.com", "press@work.example.co.uk"]
        )
    }

    @Test func urlsShareAType() {
        #expect(
            sameTypeTexts(to: "https://ada.example", among: Self.contactCard)
                == ["https://ada.example", "www.analytical.example/engine"]
        )
    }

    @Test func phonesShareAType() {
        #expect(
            sameTypeTexts(to: "(020) 7946-0000", among: Self.contactCard) == ["+44 20 7946 0958", "(020) 7946-0000"]
        )
    }

    @Test func handlesShareAType() {
        #expect(sameTypeTexts(to: "@babbage", among: Self.contactCard) == ["@ada_lovelace", "@babbage"])
    }

    @Test func emailAndHandleAreDifferentTypes() {
        #expect(sameTypeTexts(to: "@ada", among: ["ada@example.com", "@ada"]) == ["@ada"])
        #expect(sameTypeTexts(to: "ada@example.com", among: ["ada@example.com", "@ada"]) == ["ada@example.com"])
    }

    @Test func wholeLabelledLineHasNoType() {
        #expect(
            sameTypeTexts(to: "Email: ada@example.com", among: ["Email: ada@example.com", "Work: ada@work.example"])
                == ["Email: ada@example.com"]
        )
    }

    @Test func shortNumbersTimesAndYearsAreNotPhones() {
        #expect(sameTypeTexts(to: "10:30", among: ["10:30", "2021 - 2024", "2021-2024", "12345"]) == ["10:30"])
        #expect(sameTypeTexts(to: "2021-2024", among: ["2021-2024", "+44 20 7946 0958"]) == ["2021-2024"])
    }

    @Test func untypedChosenReturnsOnlyItself() {
        #expect(sameTypeTexts(to: "London", among: Self.contactCard) == ["London"])
    }

    @Test func chosenNotAmongCandidatesReturnsOnlyItself() {
        #expect(sameTypeTexts(to: "other@example.org", among: Self.contactCard) == ["other@example.org"])
    }

    @Test func chosenInADifferentEncodingThanItsCandidateReturnsOnlyItself() {
        let decomposed = "https://zu\u{0308}rich.example"

        #expect(
            sameTypeTexts(to: decomposed, among: ["https://z\u{00FC}rich.example", "https://ada.example"])
                == [decomposed]
        )
    }

    @Test func singleEmailAmongOtherTypesReturnsOnlyItself() {
        #expect(
            sameTypeTexts(to: "ada@example.com", among: ["ada@example.com", "https://ada.example", "@ada"])
                == ["ada@example.com"]
        )
    }
}
