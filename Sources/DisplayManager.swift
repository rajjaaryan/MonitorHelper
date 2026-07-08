import AppKit
import Combine
import CoreGraphics

/// The two arrangements the app toggles between.
enum Layout: String {
    case left    // laptop to the left of the external monitor
    case below   // laptop below the external monitor

    /// User-facing label, e.g. "Laptop → Left".
    var label: String {
        switch self {
        case .left:  return "Laptop → Left"
        case .below: return "Laptop → Below"
        }
    }

    var opposite: Layout {
        switch self {
        case .left:  return .below
        case .below: return .left
        }
    }
}

/// Owns all Quartz Display Services interaction: enumerating displays and
/// applying / reading the arrangement. Published state drives the menu + HUD.
final class DisplayManager: ObservableObject {
    static let shared = DisplayManager()

    /// The current arrangement, or `nil` when no external monitor is attached.
    @Published private(set) var currentLayout: Layout?
    /// Whether a built-in + external pair is currently connected.
    @Published private(set) var hasExternalDisplay: Bool = false

    init() {
        refresh()
    }

    // MARK: - Enumeration

    private func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// The built-in panel + the first active external display, keyed by
    /// `CGDisplayIsBuiltin` so it survives display IDs changing on hotplug.
    private func displayPair() -> (builtin: CGDirectDisplayID, external: CGDirectDisplayID)? {
        let ids = onlineDisplays().filter { CGDisplayIsActive($0) != 0 }
        guard let builtin = ids.first(where: { CGDisplayIsBuiltin($0) != 0 }),
              let external = ids.first(where: { CGDisplayIsBuiltin($0) == 0 }) else { return nil }
        return (builtin, external)
    }

    // MARK: - State

    /// Re-read the live display configuration and republish state.
    func refresh() {
        let layout = computeCurrentLayout()
        let hasExternal = displayPair() != nil
        if Thread.isMainThread {
            currentLayout = layout
            hasExternalDisplay = hasExternal
        } else {
            DispatchQueue.main.async {
                self.currentLayout = layout
                self.hasExternalDisplay = hasExternal
            }
        }
    }

    private func computeCurrentLayout() -> Layout? {
        guard let (builtin, external) = displayPair() else { return nil }
        let lap = CGDisplayBounds(builtin)
        let ext = CGDisplayBounds(external)
        // "below" when the laptop's top edge sits at/under the external's bottom edge.
        return lap.origin.y >= ext.maxY - 1 ? .below : .left
    }

    // MARK: - Apply / toggle

    /// Apply an arrangement. External stays primary at (0,0); only the laptop moves.
    /// Returns `false` (and does nothing) when no external monitor is attached.
    @discardableResult
    func apply(_ layout: Layout) -> Bool {
        guard let (builtin, external) = displayPair() else { return false }
        let ext = CGDisplayBounds(external)
        let lap = CGDisplayBounds(builtin)

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else {
            return false
        }

        // External monitor anchored as primary at the global origin.
        CGConfigureDisplayOrigin(cfg, external, 0, 0)

        switch layout {
        case .left:
            let y = Int32(max(0, (ext.height - lap.height) / 2))   // vertically centered
            CGConfigureDisplayOrigin(cfg, builtin, Int32(-lap.width), y)  // immediately left of monitor
        case .below:
            let x = Int32(max(0, (ext.width - lap.width) / 2))     // horizontally centered
            CGConfigureDisplayOrigin(cfg, builtin, x, Int32(ext.height))
        }

        guard CGCompleteDisplayConfiguration(cfg, .permanently) == .success else {
            return false
        }

        refresh()
        return true
    }

    /// Apply whichever layout is *not* currently active.
    /// Returns the newly-applied layout, or `nil` when there's nothing to toggle.
    @discardableResult
    func toggle() -> Layout? {
        guard let current = computeCurrentLayout() else { return nil }
        let next = current.opposite
        return apply(next) ? next : nil
    }
}
