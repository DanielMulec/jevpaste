import AppKit

/// The borderless floating panel that jevpaste shows below the status item. It never activates the app when
/// clicked and is never main. The Candidate Chooser's and the history panel's may become key, the indicator's only
/// while it offers to paste everything after No Suitable Match; each reports when it stops being key.
final class StatusItemPanel: NSPanel {
    var onResignKey: (@MainActor () -> Void)?
    /// Whether the panel may become key; the indicator switches it on only for its offer.
    var becomesKey: Bool

    init(becomesKey: Bool) {
        self.becomesKey = becomesKey
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true
        )
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { becomesKey }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

/// The rounded background of jevpaste's panels, holding one view that fills it: the dark HUD material for the
/// indicator and the chooser; the history panel passes `.popover`, which follows light and dark appearance.
final class HUDBackgroundView: NSVisualEffectView {
    init(filledBy content: NSView, material: NSVisualEffectView.Material = .hudWindow, cornerRadius: Double = 8) {
        super.init(frame: .zero)
        self.material = material
        state = .active
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        addFillingSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

/// A view that takes every click inside it, including the first one into an inactive panel, and forwards it.
/// `@MainActor` is inherited from `NSView`; it is spelled out because without it the compiler mangled `onClick`
/// inconsistently across batches once `Chooser/` and `History/` coexisted (undefined symbol at link time).
@MainActor
class FirstClickView: NSView {
    var onClick: (@MainActor () -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

extension NSView {
    /// Adds `subview` pinned to all four edges, so this view takes the subview's fitting size.
    func addFillingSubview(_ subview: NSView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor),
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
