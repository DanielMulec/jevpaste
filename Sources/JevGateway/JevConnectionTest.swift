import SmartPasteCore

/// What Settings' Test button found.
public enum JevConnectionTestResult: Equatable, Sendable {
    case works
    case failed(JevConnectionTestFailure)
}

/// Why the connection test did not work; no key, no body, safe to show and log.
public enum JevConnectionTestFailure: Equatable, Sendable {
    case noKey
    /// 401 or 403: the provider does not accept the key.
    case keyRejected(status: Int)
    case rateLimited
    case noConnection
    case httpStatus(Int)
    /// A 200 whose answer was not the one offered option.
    case unexpectedAnswer
}

extension JevGatewayAccess {
    /// One choice question with a single option — the cheapest request Jev answers.
    static let connectionTestRequest = NarrowingRequest(
        sourceDocument: "JevPaste connection test", targetContext: TargetContext(), excerpts: [],
        questions: [
            ChoiceQuestion(
                id: "connection_test", instructions: .wholeCopy("Choose the only option."),
                options: [ChoiceOption(id: "ok", description: .text("The only option."))]
            )
        ]
    )

    /// Sends one cheap request with `provider`'s saved key, the way a Paste Attempt would, and replies once on the
    /// main actor.
    public func testConnection(
        of provider: JevProvider, reply: @escaping @MainActor @Sendable (JevConnectionTestResult) -> Void
    ) {
        guard let service = decisionService(for: provider) else { return reply(.failed(.noKey)) }
        service.evaluateReportingStatus(Self.connectionTestRequest) { narrowingReply, status in
            reply(Self.result(of: narrowingReply, status: status))
        }
    }

    private static func result(of reply: NarrowingReply, status: Int?) -> JevConnectionTestResult {
        switch (reply, status) {
        case (.answered, _): .works
        case (.rateLimited, _): .failed(.rateLimited)
        case (_, nil): .failed(.noConnection)
        case (_, 401), (_, 403): .failed(.keyRejected(status: status ?? 0))
        case (_, 200): .failed(.unexpectedAnswer)
        case (_, let status?): .failed(.httpStatus(status))
        }
    }
}
