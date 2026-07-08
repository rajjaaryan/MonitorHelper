import AppKit
import Carbon.HIToolbox

/// Wires up the global hotkey and keeps display state fresh. All UI lives in the
/// SwiftUI `MenuBarExtra`; this delegate only handles the AppKit-level plumbing.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background/menu-bar agent — no Dock icon (also set via LSUIElement).
        NSApp.setActivationPolicy(.accessory)

        // ⌃⌥⌘D toggles the arrangement. (Cmd/Ctrl included to dodge FB15168205.)
        HotKeyManager.shared.onTrigger = {
            AppController.shared.toggle()
        }
        HotKeyManager.shared.register(
            keyCode: UInt32(kVK_ANSI_D),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )

        // Keep menu + HUD state in sync when displays are attached/detached/rearranged.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in
            DisplayManager.shared.refresh()
        }

        // Design/preview hook: MH_PREVIEW_HUD=left|below shows the HUD on launch
        // without moving displays. Harmless in normal use (env var unset).
        if let preview = ProcessInfo.processInfo.environment["MH_PREVIEW_HUD"],
           let layout = Layout(rawValue: preview) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                AppController.shared.previewHUD(layout)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
}
