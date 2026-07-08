import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hotkey via Carbon `RegisterEventHotKey`.
///
/// Carbon hotkeys register one specific key combo at the system level, so —
/// unlike `NSEvent` global monitors — they do NOT require the Accessibility
/// permission. The event handler runs on the main run loop.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Called (on the main thread) when the hotkey fires.
    var onTrigger: (() -> Void)?

    private let signature: OSType = 0x4D4E4854 // 'MNHT'

    func register(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))

        // Non-capturing C callback (references only the global singleton).
        let callback: EventHandlerUPP = { _, _, _ in
            HotKeyManager.shared.onTrigger?()
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
