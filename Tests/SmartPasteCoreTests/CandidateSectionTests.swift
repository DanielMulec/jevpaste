import SmartPasteCore
import Testing

/// Whether `text` derives a Candidate whose UTF-8 bytes equal `excerpt`'s.
private func derives(_ excerpt: String, from text: String) -> Bool {
    derivedCandidateTexts(of: text).contains { $0.utf8.elementsEqual(excerpt.utf8) }
}

/// The derived Candidates that span a line break.
private func multiLineTexts(of text: String) -> [String] {
    derivedCandidateTexts(of: text).filter { $0.contains(where: \.isNewline) }
}

struct CandidateSectionTests {
    @Test func colonHeadingLeadsASectionUntilTheNextBlankLine() {
        let source = "Ada Lovelace\nExperience:\nLead, Analytical Engines\nAuthor, Notes\n\nLondon"

        #expect(derives("Experience:\nLead, Analytical Engines\nAuthor, Notes", from: source))
    }

    @Test func markdownHeadingLeadsASection() {
        #expect(derives("## Skills\nSwift\nMathematics", from: "Profile text\n## Skills\nSwift\nMathematics"))
    }

    @Test func upperCaseHeadingLeadsASectionEvenWhenItsFirstBodyLineIsUpperCase() {
        let source = "Ada Lovelace\nEXPERIENCE\nCEO\nAnalytical Engines, London"

        #expect(derives("EXPERIENCE\nCEO\nAnalytical Engines, London", from: source))
        #expect(derives("CEO\nAnalytical Engines, London", from: source))
    }

    @Test func lineFollowedByDeeperIndentedLinesLeadsASection() {
        let source = "Name: Ada\nAddress\n  221B Baker Street\n  London\nPhone: +44 20 7946 0958"

        #expect(derives("Address\n  221B Baker Street\n  London", from: source))
    }

    @Test func shortLineAfterABlankLineLeadsASection() {
        let source = "Ada Lovelace\n\nWork History\nLead, Analytical Engines\nEDUCATION\nPrivate tutoring"

        #expect(derives("Work History\nLead, Analytical Engines", from: source))
        #expect(derives("EDUCATION\nPrivate tutoring", from: source))
    }

    @Test func sectionEndsBeforeTheNextHeadingLikeLine() {
        let source = "Skills:\nSwift\nMathematics\n## Languages\nEnglish\nFrench"

        #expect(derives("Skills:\nSwift\nMathematics", from: source))
        #expect(derives("## Languages\nEnglish\nFrench", from: source))
    }

    @Test func sectionEndsBeforeALineIndentedLessThanItsBody() {
        let source = "Contact:\n\tada@example.com\n\t+44 20 7946 0958\nNotes follow here"

        #expect(multiLineTexts(of: source) == [source, "Contact:\n\tada@example.com\n\t+44 20 7946 0958"])
    }

    @Test func headingWithoutBodyYieldsNoSection() {
        #expect(multiLineTexts(of: "Ada\nSkills:\n\nSwift") == ["Ada\nSkills:\n\nSwift", "Ada\nSkills:"])
    }

    @Test func labelledLinesAndShortLinesInsideAParagraphAreNotHeadingLike() {
        let source = "Ada Lovelace\nEmail: ada@example.com\nLondon\nEngland"

        #expect(multiLineTexts(of: source) == [source])
    }

    @Test func multiLineCandidatesComeInDocumentOrderContainersFirst() {
        #expect(
            derivedCandidateTexts(of: "Contact:\nada@example.com\n\nSkills:\nSwift")
                == [
                    "Contact:\nada@example.com\n\nSkills:\nSwift", "Contact:\nada@example.com", "Contact:",
                    "ada@example.com", "Skills:\nSwift", "Skills:", "Swift",
                ]
        )
    }
}
