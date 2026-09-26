import SmartPasteCore

extension OrderedJSON {
    /// The value of the object member `key`; `nil` when this is not an object or has no such member.
    subscript(key: String) -> OrderedJSON? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }

    var stringValue: String? {
        guard case .string(let text) = self else { return nil }
        return text
    }

    var objectMembers: [Member]? {
        guard case .object(let members) = self else { return nil }
        return members
    }

    var arrayElements: [OrderedJSON]? {
        guard case .array(let elements) = self else { return nil }
        return elements
    }
}
