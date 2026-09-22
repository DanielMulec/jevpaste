import Foundation

/// Sends one HTTP request and returns the response, whatever its status. The seam that keeps unit tests offline.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The production transport: one `URLSession` data task per request, no retry of its own.
public struct URLSessionTransport: HTTPTransport {
    struct NonHTTPResponse: Error {}

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NonHTTPResponse() }
        return (data, httpResponse)
    }
}
