import Foundation
import SmartPasteCore

/// The three answers the adapter reads from a `200` evaluation; everything else in the body is ignored.
struct EvaluateResponse: Decodable {
    let answers: EvaluateAnswers

    /// Maps Jev's answer onto the Candidates that were offered, by option id.
    static func decision(from body: Data, offered candidates: [Candidate]) -> Result<Decision, JevGatewayFailure> {
        guard let answers = try? JSONDecoder().decode(EvaluateResponse.self, from: body).answers else {
            return .failure(.malformedResponse)
        }
        let containsValue = answers.containsValue.probability
        let freeText = answers.freeText.probability
        guard (0...1).contains(containsValue), (0...1).contains(freeText) else { return .failure(.malformedResponse) }
        guard let choice = choice(forOptionID: answers.paste.choice, among: candidates) else {
            return .failure(.unknownChoice)
        }
        return .success(
            Decision(choice: choice, containsValueProbability: containsValue, freeTextProbability: freeText)
        )
    }

    private static func choice(forOptionID optionID: String, among candidates: [Candidate]) -> Decision.Choice? {
        if optionID == EvaluateRequestBody.noneOfTheseOptionID { return .noneOfThese }
        let index = candidates.indices.first { EvaluateRequestBody.optionID(forCandidateAt: $0) == optionID }
        return index.map { .candidate(candidates[$0]) }
    }
}

struct EvaluateAnswers: Decodable {
    let paste: ChoiceAnswer
    let containsValue: BooleanAnswer
    let freeText: BooleanAnswer

    enum CodingKeys: String, CodingKey {
        case paste
        case containsValue = "contains_value"
        case freeText = "free_text"
    }
}

struct ChoiceAnswer: Decodable {
    let choice: String
}

struct BooleanAnswer: Decodable {
    let probability: Double
}
