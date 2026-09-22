/// Collects the bounded window of visible text around a Target for Target Context.
///
/// Pages and app windows are walked breadth-first from the nearest page (`AXWebArea`), else the window, and
/// the text is cut after the first `characterLimit` characters. A terminal exposes its whole window as the
/// Target's own value, so it gets the last `characterLimit` characters of that value: the lines nearest the
/// prompt. Secure fields are skipped without reading them. AX does not report visibility; exposed text counts.
@MainActor
struct SurroundingTextCollector<Node: AccessibilityNode> {
    /// Terminals whose single text area is a scrape of the entire window (probe: Ghostty, one `AXTextArea`).
    static var terminalBundleIdentifiers: Set<String> {
        [
            "com.mitchellh.ghostty", "com.apple.Terminal", "com.googlecode.iterm2", "net.kovidgoyal.kitty",
            "org.alacritty", "com.github.wez.wezterm", "dev.warp.Warp-Stable",
        ]
    }

    let characterLimit = 2_000
    let nodeLimit = 600

    /// The surrounding text, gathered only until `deadline`.
    func surroundingText(of focused: FocusedElement<Node>, until deadline: ContinuousClock.Instant) -> String {
        if Self.terminalBundleIdentifiers.contains(focused.bundleIdentifier ?? "") {
            return String((focused.node.text(of: .value) ?? "").suffix(characterLimit))
        }
        let scope = scope(of: focused.node, until: deadline)
        return String(pageText(from: scope, until: deadline).prefix(characterLimit))
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
