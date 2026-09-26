// PROTOTYPE — menu-settings, never merged
import AppKit

/// The Settings window in three layouts (question 3): 1 = toolbar tabs, 2 = sidebar + grouped form, 3 = one page.
/// Every layout can open to `.key(provider)`, where "No key for <provider> — open Settings" lands.
@MainActor
final class SettingsWindows {
    private let state = ProtoState.shared
    private var window: NSWindow?
    private var builtVariant = 0
    private var keyRows: [JevProvider: KeyRow] = [:]
    private var history: FullHistoryList?
    private var labels: [NSTextField] = []
    private var refreshers: [() -> Void] = []
    private var select: ((SettingsSection) -> Void)?

    func open(_ section: SettingsSection) {
        if window == nil || builtVariant != state.settingsVariant { build() }
        guard let window else { return }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        select?(section)
        if case let .key(provider) = section {
            keyRows[provider]?.markMissing()
            ProtoHooks.shared.after(0.15) { self.keyRows[provider]?.focus() }
        }
        state.note("Settings \(state.settingsVariant) opened to \(section)")
        ProtoHooks.shared.windowReady(window, name: "settings")
    }

    func stateChanged() {
        for label in labels { label.stringValue = state.label }
        for row in keyRows.values { row.refresh() }
        history?.reload()
        for refresh in refreshers { refresh() }
        if let window, window.isVisible, builtVariant != state.settingsVariant {
            let frame = window.frame
            window.orderOut(nil)
            open(.general)
            self.window?.setFrameTopLeftPoint(NSPoint(x: frame.minX, y: frame.maxY))
        }
    }

    private func build() {
        window?.orderOut(nil)
        keyRows = [:]
        labels = []
        refreshers = []
        builtVariant = state.settingsVariant
        history = FullHistoryList(height: state.settingsVariant == 3 ? 240 : 330)
        switch state.settingsVariant {
        case 2: window = buildSidebar()
        case 3: window = buildOnePage()
        default: window = buildTabs()
        }
        window?.isReleasedWhenClosed = false
        window?.center()
    }

    // MARK: shared pieces

    private func label() -> NSTextField {
        let label = stateLabel()
        labels.append(label)
        return label
    }

    private func loginSwitch() -> NSView {
        let toggle = NSSwitch()
        toggle.state = state.openAtLogin ? .on : .off
        let action = ClosureTarget { [weak toggle] in
            ProtoState.shared.openAtLogin = toggle?.state == .on
            ProtoState.shared.note("Open at Login: \(toggle?.state == .on ? "on" : "off")")
        }
        toggle.target = action
        toggle.action = #selector(ClosureTarget.fire)
        objc_setAssociatedObject(toggle, "action", action, .OBJC_ASSOCIATION_RETAIN)
        let title = NSTextField(labelWithString: "Open at Login")
        return NSStackView(views: [title, NSView(), toggle])
    }

    private func providerRadios() -> NSView {
        let buttons = JevProvider.allCases.map { provider -> NSButton in
            let title = provider == .gateway ? "\(provider.rawValue) (default)" : provider.rawValue
            let button = NSButton(radioButtonWithTitle: title, target: nil, action: nil)
            button.state = state.provider == provider ? .on : .off
            let action = ClosureTarget { ProtoState.shared.provider = provider }
            button.target = action
            button.action = #selector(ClosureTarget.fire)
            objc_setAssociatedObject(button, "action", action, .OBJC_ASSOCIATION_RETAIN)
            return button
        }
        let stack = NSStackView(views: buttons)
        stack.orientation = .vertical
        stack.alignment = .leading
        let hint = NSTextField(wrappingLabelWithString:
            "Every Smart Paste goes through the chosen Jev Provider. Without its key, ⌘⇧V refuses — "
            + "it never switches to the other provider.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 440
        return column([stack, hint], spacing: 6)
    }

    private func keyRow(_ provider: JevProvider, _ show: KeyRow.ShowStyle, _ placement: KeyRow.ResultPlacement,
                        width: Double = 300) -> KeyRow {
        let row = KeyRow(provider: provider, show: show, placement: placement, width: width)
        keyRows[provider] = row
        return row
    }

    private func column(_ views: [NSView], spacing: Double = 14, inset: Double = 0) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.edgeInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        return stack
    }

    private func heading(_ text: String, size: Double = 13) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: .semibold)
        return field
    }

    private func pinWidth(_ view: NSView, _ width: Double) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    // MARK: 1 — toolbar tabs

    private func buildTabs() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        let general = column([loginSwitch(), NSView(), label()], inset: 24)
        let gatewayKey = keyRow(.gateway, .eyeButton, .inline)
        let typesafeKey = keyRow(.typesafe, .eyeButton, .inline)
        let provider = column([
            heading("Jev Provider"), providerRadios(), heading("API keys"),
            heading("Vercel AI Gateway", size: 11), gatewayKey.view,
            heading("Typesafe direct", size: 11), typesafeKey.view, NSView(), label(),
        ], inset: 24)
        let full = column([history!.view, NSView(), label()], inset: 20)
        for (view, width) in [(general, 620.0), (provider, 620), (full, 620)] { pinWidth(view, width) }
        pinWidth(history!.view, 580)
        let items: [(String, String, NSView, Double)] = [
            ("General", "gearshape", general, 150), ("Jev Provider", "bolt.horizontal", provider, 430),
            ("Full History", "clock.arrow.circlepath", full, 480),
        ]
        for (title, symbol, view, height) in items {
            let controller = NSViewController()
            controller.view = view
            controller.title = title
            controller.preferredContentSize = NSSize(width: 620, height: height)
            let item = NSTabViewItem(viewController: controller)
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        select = { section in
            switch section {
            case .general: tabs.selectedTabViewItemIndex = 0
            case .provider, .key: tabs.selectedTabViewItemIndex = 1
            case .fullHistory: tabs.selectedTabViewItemIndex = 2
            }
            let size = tabs.tabViewItems[tabs.selectedTabViewItemIndex].viewController?.preferredContentSize ?? .zero
            let top = window.frame.maxY
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
            frame.origin = NSPoint(x: window.frame.minX, y: top - frame.height)
            window.setFrame(frame, display: true)
        }
        return window
    }

    // MARK: 2 — sidebar + grouped form

    private func buildSidebar() -> NSWindow {
        let gatewayKey = keyRow(.gateway, .checkbox, .below, width: 330)
        let typesafeKey = keyRow(.typesafe, .checkbox, .below, width: 330)
        let panes: [(String, String, NSView)] = [
            ("General", "gearshape", column([heading("General", size: 17), group([loginSwitch()]), label()],
                                            inset: 24)),
            ("Jev Provider", "bolt.horizontal", column([
                heading("Jev Provider", size: 17), group([providerRadios()]),
                heading("Vercel AI Gateway API key", size: 11), group([gatewayKey.view]),
                heading("Typesafe direct API key", size: 11), group([typesafeKey.view]), label(),
            ], inset: 24)),
            ("Full History", "clock.arrow.circlepath", column([heading("Full History", size: 17), history!.view,
                                                              label()], inset: 24)),
        ]
        let content = NSView()
        let sidebar = SidebarList(entries: panes.map { ($0.0, $0.1) })
        func show(_ index: Int) {
            content.subviews.forEach { $0.removeFromSuperview() }
            let pane = panes[index].2
            pane.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(pane)
            NSLayoutConstraint.activate([
                pane.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                pane.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                pane.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            ])
            sidebar.select(index)
        }
        pinWidth(history!.view, 450)
        sidebar.onSelect = { show($0) }
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(sidebar.view)
        split.addArrangedSubview(content)
        pinWidth(sidebar.view, 190)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Settings"
        window.contentView = split
        select = { section in
            switch section {
            case .general: show(0)
            case .provider, .key: show(1)
            case .fullHistory: show(2)
            }
        }
        return window
    }

    /// A System-Settings-style rounded group.
    private func group(_ views: [NSView]) -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 8
        box.layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        box.layer?.borderColor = NSColor.separatorColor.cgColor
        box.layer?.borderWidth = 1
        let inner = column(views, spacing: 8)
        inner.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            inner.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor, constant: -12),
            inner.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            inner.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),
        ])
        pinWidth(box, 450)
        return box
    }

    // MARK: 3 — one scrolling page

    private func buildOnePage() -> NSWindow {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: JevProvider.allCases.map(\.rawValue))
        popup.selectItem(withTitle: state.provider.rawValue)
        let providerAction = ClosureTarget { [weak popup] in
            ProtoState.shared.provider = JevProvider(rawValue: popup?.titleOfSelectedItem ?? "") ?? .gateway
        }
        popup.target = providerAction
        popup.action = #selector(ClosureTarget.fire)
        objc_setAssociatedObject(popup, "action", providerAction, .OBJC_ASSOCIATION_RETAIN)
        let providerHeader = NSTextField(labelWithString: "")
        var keyViews: [JevProvider: NSView] = [:]
        var collapsed: [JevProvider: NSButton] = [:]
        for provider in JevProvider.allCases {
            let row = keyRow(provider, .eyeButton, .external, width: 330)
            row.onResult = { [weak self] _ in self?.refreshers.forEach { $0() } }
            keyViews[provider] = row.view
            let other = NSButton(title: "", target: nil, action: nil)
            other.isBordered = false
            let expand = ClosureTarget { [weak self] in
                keyViews[provider]?.isHidden.toggle()
                self?.refreshers.forEach { $0() }
                self?.state.note("\(provider.rawValue) key row toggled")
            }
            other.target = expand
            other.action = #selector(ClosureTarget.fire)
            objc_setAssociatedObject(other, "action", expand, .OBJC_ASSOCIATION_RETAIN)
            collapsed[provider] = other
        }
        refreshers.append { [weak self] in
            guard let self else { return }
            let chosen = self.state.provider
            let header = NSMutableAttributedString(string: "Jev Provider   ", attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold)])
            switch self.state.testResults[chosen] ?? .none {
            case .ok: header.append(Self.badge("\(chosen.rawValue) ✓ tested", .systemGreen))
            case .failed: header.append(Self.badge("\(chosen.rawValue) ✕ test failed", .systemRed))
            case .testing: header.append(Self.badge("testing…", .secondaryLabelColor))
            case .none: header.append(Self.badge((self.state.keys[chosen] ?? "").isEmpty ? "no key" : "not tested",
                                                 .systemOrange))
            }
            providerHeader.attributedStringValue = header
            for provider in JevProvider.allCases {
                let hasKey = !(self.state.keys[provider] ?? "").isEmpty
                let open = !(keyViews[provider]?.isHidden ?? true)
                collapsed[provider]?.title = "\(open ? "▾" : "▸")  \(provider.rawValue) API key — "
                    + (hasKey ? "set" : "not set")
            }
        }
        for provider in JevProvider.allCases where provider != state.provider { keyViews[provider]?.isHidden = true }
        let keys = column(JevProvider.allCases.flatMap { [collapsed[$0]!, keyViews[$0]!] }, spacing: 8)
        let fullHeader = heading("Full History", size: 15)
        let page = column([
            heading("General", size: 15), loginSwitch(), NSBox.separator(),
            providerHeader, NSStackView(views: [NSTextField(labelWithString: "Send Smart Paste through"), popup]),
            keys, NSBox.separator(), fullHeader, history!.view, label(),
        ], spacing: 12, inset: 24)
        for view in page.arrangedSubviews where !(view is NSTextField) { pinWidth(view, 500) }
        let document = FlippedView()
        page.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(page)
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            page.topAnchor.constraint(equalTo: document.topAnchor),
            page.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = document
        document.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 548, height: 580),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.contentView = scroll
        refreshers.forEach { $0() }
        select = { section in
            document.layoutSubtreeIfNeeded()
            let target: NSView = switch section {
            case .general: page
            case .provider: providerHeader
            case let .key(provider): { keyViews[provider]?.isHidden = false; self.refreshers.forEach { $0() }
                return providerHeader }()
            case .fullHistory: fullHeader
            }
            target.scrollToVisible(target.bounds.insetBy(dx: 0, dy: -8))
            if section == .fullHistory || section != .general {
                let origin = target.convert(NSPoint.zero, to: document)
                scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, origin.y - 12)))
            }
        }
        return window
    }

    private static func badge(_ text: String, _ color: NSColor) -> NSAttributedString {
        NSAttributedString(string: " \(text) ", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: color,
            .backgroundColor: color.withAlphaComponent(0.15),
        ])
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

extension NSBox {
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

final class ClosureTarget: NSObject {
    private let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
    @objc func fire() { run() }
}
