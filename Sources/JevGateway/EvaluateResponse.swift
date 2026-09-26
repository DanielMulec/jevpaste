import Foundation
import SmartPasteCore

/// Jev's answers to one `200` evaluation: per question, the chosen option id and every option's probability in the
/// order Jev listed them. Everything else in the body (confidence, usage, provider metadata) is ignored.
enum EvaluateResponse {
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
