import Testing

@testable import SmartPasteCore

/// The pieces offered next to a piece unchanged. Expected counts are the spike's `r2.children2` on the same copies
/// and budgets (`spike/narrowing` @ ba32886).
struct PieceChildrenTests {
    private let policy = NarrowingPolicy.r2b

    /// The spike's step budget: the state's estimate, and 250 + 900 tokens per question at step 1.
    private func budget(stateTokens: Double) -> StepBudget {
        StepBudget(sizeModel: policy.sizeModel, stateTokens: stateTokens, questionTokens: 1150, piecesPerChoice: 252)
    }

    private func children(of text: String, stateTokens: Double = 0) -> PieceChildren {
        PieceChildren(of: text[...], policy: policy, budget: budget(stateTokens: stateTokens))
    }

    @Test func aOneLineAddressOffersEveryTokenRunAndItsEdgeCutsOnce() throws {
        let children = children(of: "Mira Holzner, Prankergasse 77, 8020 Graz")

        #expect(children.coarse.count == 40)
        #expect(children.fine.isEmpty)
        let texts: [String] = children.coarse.map(String.init)
        #expect(texts.filter { $0 == "," }.count == 1)
        #expect(texts.contains("Graz"))
        #expect(texts.contains("a Holzner, Prankergasse 77, 8020 Graz"))
    }

    @Test func thePieceItselfIsNeverAChild() {
        let ofLineWithBreak: [String] = children(of: "Graz\n").all.map(String.init)
        let ofToken: [String] = children(of: "Graz").all.map(String.init)

        #expect(ofLineWithBreak == ["Graz"])
        #expect(!ofToken.contains("Graz"))
    }

    @Test func oneTokenOffersEverySubstringAndOneCharacterNothing() {
        let ofTwoCharacters: [String] = children(of: "77").all.map(String.init)
        let ofThreeCharacters: [String] = children(of: "abc").all.map(String.init)
        #expect(ofTwoCharacters == ["7"])
        #expect(ofThreeCharacters == ["ab", "a", "bc", "b", "c"])
        #expect(children(of: "7").all.isEmpty)
    }

    @Test func canonicallyEquivalentButDifferentlyEncodedPiecesAreBothOffered() {
        let texts: [String] = children(of: "Z\u{FC}rich Zu\u{308}rich").all.map(String.init)
        let precomposed: [UInt8] = Array("Z\u{FC}rich".utf8)
        let decomposed: [UInt8] = Array("Zu\u{308}rich".utf8)

        #expect(texts.filter { Array($0.utf8) == precomposed }.count == 1)
        #expect(texts.filter { Array($0.utf8) == decomposed }.count == 1)
    }

    @Test func aMultiLineCopyOffersLineRunsEdgeCutsAndShortTokenRuns() throws {
        let address = try #require(NarrowingCell.named("A04_hausnummer")?.item)

        let children = children(of: address, stateTokens: 394.5)

        #expect(children.coarse.count == 38)
        #expect(children.fine.count == 74)
        #expect(children.coarse.first == address[...].prefix(upTo: try #require(address.lastIndex(of: "\n"))))
    }

    @Test func aTooBigCopyIsCutIntoBlocksAndSingleLinesAndItsFineRunsAreLeftOut() throws {
        let list = try #require(NarrowingCell.named("N03_list_300_lines")?.item)
        let lines = PieceCutting.lines(of: list[...])

        let children = children(of: list, stateTokens: 11890.25)

        #expect(children.fine.isEmpty)
        #expect(children.coarse.count == 302)
        #expect(children.coarse[0] == list[lines[0].startIndex..<lines[149].endIndex])
        #expect(children.coarse[1] == list[lines[150].startIndex..<lines[299].endIndex])
        #expect(Array(children.coarse[2...]) == lines)
    }
}
