import Foundation
import SmartPasteCore

/// Jev's answers to one `200` evaluation: per question, the chosen option id and every option's probability in the
/// order Jev listed them — the same on every Jev Provider. Everything else in the body (confidence, usage in either
/// spelling, provider metadata) is ignored; the answered model is read for the log only.
enum EvaluateResponse {
    private static let modelIDCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_/"))
    private static let longestModelID = 40

    /// The `model` that answered, as an id fit for the log: only ASCII letters, digits and `.-_/`, at most 40 of them;
    /// `nil` when the body names none.
    static func answeredModel(in body: Data) -> String? {
        guard let model = OrderedJSONParser.parse(body)?["model"]?.stringValue else { return nil }
        let idScalars = model.unicodeScalars.filter { $0.isASCII && modelIDCharacters.contains($0) }
        return String(String.UnicodeScalarView(idScalars.prefix(longestModelID)))
    }

    static func answers(
        from body: Data, to request: NarrowingRequest
    ) -> Result<[String: ChoiceAnswer], JevGatewayFailure> {
        guard let answers = OrderedJSONParser.parse(body)?["answers"] else { return .failure(.malformedResponse) }
        var byQuestion: [String: ChoiceAnswer] = [:]
        for question in request.questions {
            guard let answer = answers[question.id], let choice = answer["choice"]?.stringValue,
                let probabilities = probabilities(in: answer)
            else { return .failure(.malformedResponse) }
            guard question.options.contains(where: { $0.id == choice }) else { return .failure(.unknownChoice) }
            byQuestion[question.id] = ChoiceAnswer(choice: choice, probabilities: probabilities)
        }
        return .success(byQuestion)
    }

    /// `probabilities` as numbers in 0…1, in Jev's order; `nil` when missing or out of range.
    private static func probabilities(in answer: OrderedJSON) -> [OptionProbability]? {
        guard let members = answer["probabilities"]?.objectMembers else { return nil }
        var probabilities: [OptionProbability] = []
        for member in members {
            guard case .number(let probability) = member.value, (0...1).contains(probability) else { return nil }
            probabilities.append(OptionProbability(optionID: member.key, probability: probability))
        }
        return probabilities
    }
}
