/// The service through which JevPaste reaches Jev. The user picks one in Settings, with one API key per provider;
/// every request of a Paste Attempt goes through the provider chosen when it started.
public enum JevProvider: String, CaseIterable, Sendable {
    case vercelAIGateway
    case typesafeDirect

    /// Where nothing was chosen yet.
    public static let standard = JevProvider.vercelAIGateway

    /// The provider's name as the user reads it in Settings and in the refusal.
    public var displayName: String {
        switch self {
        case .vercelAIGateway: "Vercel AI Gateway"
        case .typesafeDirect: "Typesafe direct"
        }
    }
}
