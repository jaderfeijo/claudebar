import AppKit
import Combine
import SwiftUI

/// Menu bar item + dropdown panel. Replaces MenuBarExtra, whose window chrome
/// changes between macOS releases (white bands around the content on macOS 27).
@MainActor
final class StatusBarController {
    private let model: UsageModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: DropdownPanel
    private var clickMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(model: UsageModel) {
        self.model = model
        panel = DropdownPanel(rootView: MenuView(model: model))
        panel.onClose = { [weak self] in self?.didClose() }

        if let button = item.button {
            button.target = self
            button.action = #selector(toggle)
            button.wantsLayer = true
        }
        model.$windows.combineLatest(model.$connected)
            .sink { [weak self] windows, connected in
                let max = windows.map(\.utilization).max()
                self?.item.button?.title = max.map { "✳ \(Int($0.rounded()))%" } ?? (connected ? "✳" : "✳ –")
            }
            .store(in: &cancellables)
    }

    func showPanel() {
        if !panel.isVisible { show() }
    }

    @objc private func toggle() {
        if panel.isVisible {
            panel.close()
        } else {
            show()
        }
    }

    private func show() {
        guard let button = item.button, let buttonWindow = button.window else { return }
        Task { await model.refresh() }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        panel.show(below: anchor, on: buttonWindow.screen ?? NSScreen.main)
        setSelected(true)
        // Clicks on our own menu bar icon also arrive here on macOS 27; leave those
        // to toggle(), otherwise the panel closes on mouse-down and reopens on mouse-up.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if anchor.insetBy(dx: 0, dy: -2).contains(NSEvent.mouseLocation) { return }
            self?.panel.close()
        }
    }

    /// Selected pill behind the title while open — macOS 27 no longer draws one
    /// for status items that open a panel instead of an NSMenu.
    private func setSelected(_ selected: Bool) {
        guard let button = item.button, let layer = button.layer else { return }
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = selected ? NSColor.labelColor.withAlphaComponent(0.2).cgColor : nil
        }
        layer.cornerRadius = 7
    }

    private func didClose() {
        setSelected(false)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }
}

/// Borderless, translucent, rounded panel that hangs from the menu bar and
/// grows downwards as its SwiftUI content changes size.
final class DropdownPanel: NSPanel {
    var onClose: (() -> Void)?
    private var top: CGFloat?

    init<Content: View>(rootView: Content) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        contentView = NSHostingView(rootView: DropdownChrome(content: rootView))
    }

    override var canBecomeKey: Bool { true }

    func show(below anchor: NSRect, on screen: NSScreen?) {
        let size = contentView?.fittingSize ?? .zero
        let bounds = screen?.visibleFrame ?? .infinite
        let x = min(max(anchor.minX, bounds.minX + 8), bounds.maxX - size.width - 8)
        top = anchor.minY - 6
        setFrame(NSRect(x: x, y: anchor.minY - 6 - size.height, width: size.width, height: size.height), display: true)
        makeKeyAndOrderFront(nil)
    }

    /// Keep the top edge pinned when the hosting view resizes the window.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        if let top { rect.origin.y = top - rect.height }
        super.setFrame(rect, display: flag)
        invalidateShadow()
    }

    override func cancelOperation(_ sender: Any?) { close() }

    override func close() {
        super.close()
        onClose?()
    }
}

private struct DropdownChrome<Content: View>: View {
    let content: Content
    private let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)

    var body: some View {
        content
            .background(VisualEffect())
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
