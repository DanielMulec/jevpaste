/// Identifies one focused element in one process, so the Bound Target can be re-verified before insertion.
public struct TargetIdentity: Equatable, Hashable, Sendable {
    // periphery:ignore - read by the "Port the MacInterop adapters from the probe" adapter
    public let processIdentifier: Int32
    // periphery:ignore - read by the "Port the MacInterop adapters from the probe" adapter
    /// Minted by the `TargetResolver` adapter; meaningful only to that adapter.
    public let elementToken: UInt64

    public init(processIdentifier: Int32, elementToken: UInt64) {
        self.processIdentifier = processIdentifier
        self.elementToken = elementToken
    }
}

/// Information about the Target and its surroundings that helps establish what text belongs there.
public struct TargetContext: Equatable, Sendable {
    // periphery:ignore - read by the "Implement the JevGateway adapter" adapter
    public let fieldLabel: String?
    // periphery:ignore - read by the "Implement the JevGateway adapter" adapter
    public let placeholder: String?
    // periphery:ignore - read by the "Implement the JevGateway adapter" adapter
    public let sectionHeading: String?
    // periphery:ignore - read by the "Implement the JevGateway adapter" adapter
    public let siblingFieldLabels: [String]
    // periphery:ignore - read by the "Implement the JevGateway adapter" adapter
    /// A bounded window of visible text around the Target, for unlabelled Targets such as chats and terminals.
    public let surroundingText: String

    public init(
        fieldLabel: String? = nil,
        placeholder: String? = nil,
        sectionHeading: String? = nil,
        siblingFieldLabels: [String] = [],
        surroundingText: String = ""
    ) {
        self.fieldLabel = fieldLabel
        self.placeholder = placeholder
        self.sectionHeading = sectionHeading
        self.siblingFieldLabels = siblingFieldLabels
        self.surroundingText = surroundingText
    }
}

/// The Target pinned at the start of a Paste Attempt and re-verified immediately before insertion.
public struct BoundTarget: Equatable, Sendable {
    public let identity: TargetIdentity
    public let context: TargetContext
    /// The focused element is a secure text field, or secure event input is enabled.
    public let isSecureField: Bool

    public init(identity: TargetIdentity, context: TargetContext, isSecureField: Bool) {
        self.identity = identity
        self.context = context
        self.isSecureField = isSecureField
    }
}
