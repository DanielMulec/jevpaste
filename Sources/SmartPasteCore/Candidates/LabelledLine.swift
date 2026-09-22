extension Substring {
    /// The longest label a `Label: value` line may have; longer text before `": "` is prose, not a label.
    static let maximumLabelLength = 40

    /// The value of this trimmed line when it reads `Label: value`, trimmed; `nil` otherwise.
    ///
    /// The separator is the first colon followed by a space or tab. The label before it must be 1–40 characters
    /// without a colon; the value may contain colons (URLs, times) and must not be empty.
    var labelledValue: Substring? {
        guard let separator = firstLabelSeparator else { return nil }
        let label = self[startIndex..<separator]
        guard (1...Self.maximumLabelLength).contains(label.count), !label.contains(":") else { return nil }
        let value = self[index(after: separator)...].trimmingWhitespace
        return value.isEmpty ? nil : value
    }

    private var firstLabelSeparator: Index? {
        indices.first { position in
            let next = index(after: position)
            return self[position] == ":" && next < endIndex && (self[next] == " " || self[next] == "\t")
        }
    }
}
