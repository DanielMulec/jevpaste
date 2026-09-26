/// How big a Narrowing request may get, and how big a text is estimated to be — Jev's model limits and the spike's
/// token estimate, in one place (`cuts.py`, spike `spike/narrowing` @ ba32886, unchanged).
///
/// Jev's tokenizer is not public. The weights fit `usage.inputTokens` of the spike's calls and over-count Jev's real
/// count by about 1.4× (safe side). Jev refuses a request over its limits with HTTP 400 `max_tokens_exceeded`; the
/// estimate only decides how a request is shaped, never whether it is sent.
public struct NarrowingSizeModel: Equatable, Sendable {
    /// Jev's limit (TypeSafe API reference): options per choice question, including the three fixed ones.
    public let optionsPerChoice: Int
    /// Jev's limit (TypeSafe Models page): tokens for `state` plus the largest single question.
    public let stateAndLargestQuestionLimit: Int
    /// Jev's limit (TypeSafe Models page): tokens for the whole request, `state` counted once.
    public let requestLimit: Int
    /// The share of each limit a request may use: headroom for digit-heavy text, which the estimate under-counts
    /// by up to 3 %.
    public let usableShare: Double
    public let tokensPerLetter: Double
    /// Digits and every other character that is not whitespace.
    public let tokensPerOtherCharacter: Double
    public let tokensPerOption: Double
    public let tokensPerQuestion: Double
    /// In the excerpt-id form, each id costs this much beyond its text in `excerpts`.
    public let tokensPerExcerptID: Double
    /// What one question's instructions and fixed options are budgeted at when a step's pieces are cut and split.
    public let questionAllowance: Double

    /// The values the spike measured and ran with.
    public static let r2b = NarrowingSizeModel(
        optionsPerChoice: 255, stateAndLargestQuestionLimit: 32_000, requestLimit: 64_000, usableShare: 0.92,
        tokensPerLetter: 0.25, tokensPerOtherCharacter: 1.0, tokensPerOption: 12, tokensPerQuestion: 250,
        tokensPerExcerptID: 4, questionAllowance: 900
    )

    /// State plus the largest question may use this many estimated tokens.
    var questionBudget: Double { Double(Int(Double(stateAndLargestQuestionLimit) * usableShare)) }
    /// The whole request may use this many estimated tokens.
    var requestBudget: Double { Double(Int(Double(requestLimit) * usableShare)) }

    /// Letters cost a quarter token, whitespace nothing, every other character one: per Unicode scalar, as the
    /// spike counted per code point.
    func estimatedTokens(of text: some StringProtocol) -> Double {
        var letters = 0
        var others = 0
        for scalar in text.unicodeScalars {
            switch scalar.isASCII ? Self.asciiKinds[Int(scalar.value)] : ScalarKind(scalar) {
            case .whitespace: continue
            case .letter: letters += 1
            case .other: others += 1
            }
        }
        return Double(letters) * tokensPerLetter + Double(others) * tokensPerOtherCharacter
    }

    /// What one piece costs as an option of a full-text choice.
    func optionTokens(of piece: some StringProtocol) -> Double {
        estimatedTokens(of: piece) + tokensPerOption
    }
}

extension NarrowingSizeModel {
    /// What a Unicode scalar costs: whitespace nothing, a letter (Python's `str.isalpha`: the Unicode letter
    /// categories) a quarter token, anything else one.
    fileprivate enum ScalarKind {
        case whitespace, letter, other

        init(_ scalar: Unicode.Scalar) {
            let properties = scalar.properties
            if properties.isWhitespace {
                self = .whitespace
                return
            }
            switch properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: self = .letter
            default: self = .other
            }
        }
    }

    /// The kinds of the ASCII scalars, looked up once: most text is ASCII, and the Unicode property lookups dominate
    /// the estimate's cost otherwise.
    fileprivate static let asciiKinds = (0..<128).map { ScalarKind(Unicode.Scalar(UInt8($0))) }
}
