/// A range an element reports as its text selection (`AXSelectedTextRange`): UTF-16 offsets into its own text, as
/// reported and unvalidated. An empty range is the text cursor (insertion point).
struct SelectedTextRange: Equatable {
    let location: Int
    let length: Int
}

/// The part of a field's own text that is nearby: `characterLimit` characters around the text cursor, three
/// quarters of them before it (what the user has been reading or writing into) and a quarter after. A side with
/// less text hands its unused share to the other. Without a usable cursor, the end of the text.
///
/// Counted in Characters; the reported UTF-16 cursor is converted once, rounded down to a Character boundary, so no
/// edge of the window splits a grapheme cluster or a surrogate pair.
struct CursorTextWindow {
    let characterLimit: Int

    private var charactersBeforeCursor: Int { characterLimit * 3 / 4 }

    func text(of ownText: String, cursor: SelectedTextRange?) -> Substring {
        guard let anchor = anchor(in: ownText, cursor: cursor) else { return ownText.suffix(characterLimit) }
        let preferredAfter = ownText[anchor...].prefix(characterLimit - charactersBeforeCursor)
        let before = ownText[..<anchor].suffix(characterLimit - preferredAfter.count)
        let after = ownText[anchor...].prefix(characterLimit - before.count)
        return ownText[before.startIndex..<after.endIndex]
    }

    /// Where the window is anchored: a reported range's start, if the range lies within the text. The empty range at
    /// the very start is no cursor (Gate A: Ghostty reports it whatever its cursor).
    private func anchor(in text: String, cursor: SelectedTextRange?) -> String.Index? {
        let utf16Length = text.utf16.count
        guard let cursor, cursor.location >= 0, cursor.length >= 0, cursor.location <= utf16Length,
            cursor.length <= utf16Length - cursor.location, cursor != SelectedTextRange(location: 0, length: 0)
        else { return nil }
        var index = String.Index(utf16Offset: cursor.location, in: text)
        while index.samePosition(in: text) == nil {
            index = text.utf16.index(before: index)
        }
        return index
    }
}
