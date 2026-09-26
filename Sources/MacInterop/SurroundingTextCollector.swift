/// Collects the bounded window of visible text around a Target for Target Context. One rule for every app; no app
/// identity decides anything here.
///
/// A focused field whose own text is longer than `characterLimit` (a terminal exposes its whole window that way, a
/// long document or textarea too) gives the window of that text around its text cursor (`CursorTextWindow`).
/// Otherwise the page is walked breadth-first from the nearest page (`AXWebArea`), else the window, and the text is
/// cut after the first `characterLimit` characters. Secure fields are skipped without reading them. AX does not
/// report visibility; exposed text counts.
@MainActor
struct SurroundingTextCollector<Node: AccessibilityNode> {
    let characterLimit = 2_000
    let nodeLimit = 600

    /// The surrounding text, gathered only until `deadline`.
    func surroundingText(of focused: FocusedElement<Node>, until deadline: ContinuousClock.Instant) -> String {
        let target = focused.node
        if let ownText = longOwnText(of: target) {
            let cursor = ContinuousClock.now < deadline ? target.selectedTextRange : nil
            return String(CursorTextWindow(characterLimit: characterLimit).text(of: ownText, cursor: cursor))
        }
        let scope = scope(of: target, until: deadline)
        return String(pageText(from: scope, until: deadline).prefix(characterLimit))
    }

    /// The Target's own text when it is longer than `characterLimit`; a secure field's is never read.
    private func longOwnText(of target: Node) -> String? {
        guard !target.isSecureTextField, let ownText = target.text(of: .value),
            !ownText.dropFirst(characterLimit).isEmpty
        else { return nil }
        return ownText
    }

    /// The nearest page above the Target, else its window, else the highest ancestor reached within
    /// `AccessibilityWalkLimits.ancestorDepth` levels (parent chains can be cyclic) and the time budget.
    private func scope(of target: Node, until deadline: ContinuousClock.Instant) -> Node {
        var scope = target
        for _ in 0..<AccessibilityWalkLimits.ancestorDepth {
            guard ContinuousClock.now < deadline, !TargetContextReader<Node>.isPageOrWindow(scope),
                let parent = scope.parent
            else { break }
            scope = parent
        }
        return scope
    }

    /// Breadth-first text of `root`'s subtree, one line per element, stopping at any of the four limits.
    private func pageText(from root: Node, until deadline: ContinuousClock.Instant) -> String {
        var lines: [String] = []
        var collectedCharacters = 0
        var queue = [root]
        var next = 0
        let isWithinBudget = {
            next < nodeLimit && collectedCharacters < characterLimit && ContinuousClock.now < deadline
        }
        while next < queue.count, isWithinBudget() {
            let node = queue[next]
            next += 1
            guard !node.isSecureTextField else { continue }
            if let line = node.firstText(of: [.value, .title, .description]) {
                lines.append(line)
                collectedCharacters += line.count + 1
            }
            queue.append(contentsOf: node.children(upTo: AccessibilityWalkLimits.childrenPerElement))
        }
        return lines.joined(separator: "\n")
    }
}
