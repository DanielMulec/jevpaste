import Foundation
import JevGateway
import SmartPasteCore
import Testing

/// The `free_text` question as measured in "Spike: does Jev reliably tell free-text places from value fields?".
/// Changing it invalidates the spike's evidence, so it is pinned here word for word.
private enum FreeTextWording {
    static let instructions =
        "Judge only the place described by `target_context`, not `source_document`. Is `target_context` a "
        + "free-text place — a chat or message composer, a document or text editor, a code editor, a terminal — "
        + "where the user would paste whatever they copied, as it is? Or is it a field that expects one specific "
        + "value, such as a name, an email address, a phone number, an address line or a single short entry?"
    static let criteria = [
        "true": "A free-text place: the user would paste whatever they copied, whole.",
        "false": "A field for one specific value.",
    ]
}

/// The parts of the wire body this slice added, decoded independently of the adapter's encoding types.
private struct SentFreeTextBody: Decodable {
    let state: State
    let questions: [String: Question]

    struct State: Decodable {
        let targetContext: [String: SentValue]

        enum CodingKeys: String, CodingKey {
            case targetContext = "target_context"
        }
    }

    struct Question: Decodable {
        let type: String
        let instructions: String
        let criteria: [String: String]
    }

    /// A `target_context` value: text, or the sibling label list.
    enum SentValue: Decodable, Equatable {
        case text(String)
        case list([String])

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else {
                self = .list(try container.decode([String].self))
            }
        }
    }
}

private func sentBody(for request: DecisionRequest) async throws -> SentFreeTextBody {
    let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "c000", containsValue: 0.9))
    _ = await reply(from: try Fixture.service(transport: transport), to: request)
    let body = try #require(await transport.sentRequests.first?.httpBody)
    return try JSONDecoder().decode(SentFreeTextBody.self, from: body)
}

private func request(appName: String?, windowTitle: String?) -> DecisionRequest {
    DecisionRequest(
        sourceDocument: Fixture.request.sourceDocument,
        targetContext: TargetContext(fieldLabel: "Message", appName: appName, windowTitle: windowTitle),
        candidates: Fixture.candidates
    )
}

private func reply(toBody body: String) async throws -> DecisionReply {
    await reply(from: try Fixture.service(transport: StubTransport.answering(body: body)))
}

@Suite struct FreeTextTargetGatewayTests {
    @Test func theThirdQuestionAsksWhetherTheTargetIsAFreeTextPlaceInTheSpikesWording() async throws {
        let questions = try await sentBody(for: Fixture.request).questions

        #expect(Set(questions.keys) == ["paste", "contains_value", "free_text"])
        let freeText = try #require(questions["free_text"])
        #expect(freeText.type == "boolean")
        #expect(freeText.instructions == FreeTextWording.instructions)
        #expect(freeText.criteria == FreeTextWording.criteria)
    }

    @Test func appNameAndWindowTitleAreSentInTheTargetContext() async throws {
        let context = try await sentBody(for: request(appName: "ChatGPT", windowTitle: "New chat")).state
            .targetContext

        #expect(context["app_name"] == .text("ChatGPT"))
        #expect(context["window_title"] == .text("New chat"))
    }

    /// Decoded as the full key set of the raw JSON, so an extra key (such as a bundle id) cannot hide.
    @Test func theTargetContextCarriesExactlyTheContractedKeysAndNoBundleIdentifier() async throws {
        let fullContext = TargetContext(
            fieldLabel: "Message", placeholder: "Ask anything", sectionHeading: "Chat", siblingFieldLabels: ["Search"],
            surroundingText: "you: hello", appName: "ChatGPT", windowTitle: "New chat"
        )
        let request = DecisionRequest(
            sourceDocument: Fixture.request.sourceDocument, targetContext: fullContext, candidates: Fixture.candidates
        )
        let keys = Set(try await sentBody(for: request).state.targetContext.keys)

        #expect(
            keys == [
                "field_label", "placeholder", "section_heading", "sibling_field_labels", "surrounding_text", "app_name",
                "window_title",
            ]
        )
        #expect(!keys.contains { $0.contains("bundle") })
    }

    @Test(arguments: [nil, ""])
    func anAbsentOrEmptyAppNameAndWindowTitleAreLeftOut(value: String?) async throws {
        let context = try await sentBody(for: request(appName: value, windowTitle: value)).state.targetContext

        #expect(Set(context.keys) == ["field_label"])
    }

    @Test func theFreeTextProbabilityIsReportedAsIsForCoreToJudge() async throws {
        let body = Fixture.evaluateResponse(choice: "none_of_these", containsValue: 0.12, freeText: 0.93)

        let expected = Decision(choice: .noneOfThese, containsValueProbability: 0.12, freeTextProbability: 0.93)
        #expect(try await reply(toBody: body) == .decided(expected))
    }

    @Test(arguments: [-0.01, 1.01])
    func aFreeTextProbabilityOutsideZeroToOneFails(probability: Double) async throws {
        let body = Fixture.evaluateResponse(choice: "c001", containsValue: 0.9, freeText: probability)
        #expect(try await reply(toBody: body) == .failed)
    }

    @Test func anAnswerWithoutTheFreeTextQuestionFails() async throws {
        let body = #"{"answers":{"paste":{"choice":"c001"},"contains_value":{"probability":0.9}}}"#
        #expect(try await reply(toBody: body) == .failed)
    }
}
