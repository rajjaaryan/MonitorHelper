import AppKit
import SwiftUI

/// Manages the borderless, click-through overlay panel that shows the
/// confirmation HUD. Positions it per `AppSettings.hudPosition`, animates it in,
/// and auto-dismisses after a short delay. Rapid re-triggers coalesce into a
/// single panel that just updates its diagram.
final class HUDController {
    private let model = HUDModel()
    private let settings: AppSettings
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    // Fixed panel size (card + shadow padding). Transparent, so extra space is invisible.
    private let panelSize = CGSize(width: 480, height: 420)

    // How long the HUD stays fully visible before auto-dismissing.
    private let visibleDuration: TimeInterval = 2.5

    init(settings: AppSettings) {
        self.settings = settings
    }

    private func makePanelIfNeeded() {
        guard panel == nil else { return }
        let hosting = NSHostingView(rootView: HUDRootView(model: model))
        let rect = NSRect(origin: .zero, size: panelSize)
        hosting.frame = rect

        let p = NSPanel(contentRect: rect,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false                // shadow is drawn by the SwiftUI card
        p.ignoresMouseEvents = true        // click-through
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = hosting
        panel = p
    }

    /// Show (or refresh) the HUD for the given layout.
    /// `autoDismiss: false` keeps it on screen (used for previewing/design capture).
    func show(_ layout: Layout, autoDismiss: Bool = true) {
        makePanelIfNeeded()
        guard let panel else { NSLog("MonitorHelper: HUD panel creation failed"); return }

        model.layout = layout
        position(panel)
        panel.orderFrontRegardless()

        // Flip to visible on the next tick so SwiftUI animates from the hidden state.
        DispatchQueue.main.async { self.model.isVisible = true }

        dismissWorkItem?.cancel()
        guard autoDismiss else { return }
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration, execute: work)
    }

    private func dismiss() {
        model.isVisible = false
        // Order out only after the exit animation has played.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.model.isVisible == false else { return }
            self.panel?.orderOut(nil)
        }
    }

    private func position(_ panel: NSPanel) {
        // Show on the primary monitor (the one with the menu bar, frame origin
        // at zero) rather than NSScreen.main, which is unreliable for a
        // background agent and can resolve to the built-in panel.
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let vf = screen.visibleFrame            // respects menu bar / Dock
        let s = panelSize
        let margin: CGFloat = 72

        var x = vf.midX - s.width / 2
        var y = vf.minY + margin

        switch settings.hudPosition {
        case .bottomCenter: x = vf.midX - s.width / 2;      y = vf.minY + margin
        case .topCenter:    x = vf.midX - s.width / 2;      y = vf.maxY - s.height - margin
        case .center:       x = vf.midX - s.width / 2;      y = vf.midY - s.height / 2
        case .bottomLeft:   x = vf.minX + margin;           y = vf.minY + margin
        case .bottomRight:  x = vf.maxX - s.width - margin; y = vf.minY + margin
        case .topLeft:      x = vf.minX + margin;           y = vf.maxY - s.height - margin
        case .topRight:     x = vf.maxX - s.width - margin; y = vf.maxY - s.height - margin
        }
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }
}
