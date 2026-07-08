import AppKit

/// Coordinates the display toggle and the confirmation HUD. Shared by the
/// hotkey (via `AppDelegate`) and the menu UI so both paths behave identically.
final class AppController {
    static let shared = AppController()

    let displays = DisplayManager.shared
    let settings = AppSettings.shared
    private lazy var hud = HUDController(settings: settings)

    /// Flip to the other layout, then confirm with the HUD. Beeps if no monitor.
    func toggle() {
        if let newLayout = displays.toggle() {
            hud.show(newLayout)
        } else {
            NSSound.beep()
        }
    }

    /// Apply a specific layout, then confirm with the HUD. Beeps if no monitor.
    func apply(_ layout: Layout) {
        if displays.apply(layout) {
            hud.show(layout)
        } else {
            NSSound.beep()
        }
    }

    /// Show the HUD without changing the arrangement (used for previewing/design).
    func previewHUD(_ layout: Layout) {
        hud.show(layout, autoDismiss: false)
    }
}
