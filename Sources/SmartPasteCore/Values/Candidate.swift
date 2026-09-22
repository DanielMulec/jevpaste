/// An exact contiguous substring of the Active Item, derived locally, that Jev may choose as the Paste Result.
public struct Candidate: Equatable, Hashable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}
