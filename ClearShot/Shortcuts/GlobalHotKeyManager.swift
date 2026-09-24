import Carbon.HIToolbox
import AppKit

/// A user-editable, Codable keyboard shortcut spec: a virtual key code plus a
/// modifier mask. Deliberately not using `NSEvent.ModifierFlags` directly so
/// it can be `Codable` and stored in `UserDefaults`/`AppSettings`.
struct KeyboardShortcutSpec: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: Modifiers

    struct Modifiers: OptionSet, Codable {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)

        var carbonFlags: UInt32 {
            var flags: UInt32 = 0
            if contains(.command) { flags |= UInt32(cmdKey) }
            if contains(.shift) { flags |= UInt32(shiftKey) }
            if contains(.option) { flags |= UInt32(optionKey) }
            if contains(.control) { flags |= UInt32(controlKey) }
            return flags
        }

        var displaySymbols: String {
            var s = ""
            if contains(.control) { s += "⌃" }
            if contains(.option) { s += "⌥" }
            if contains(.shift) { s += "⇧" }
            if contains(.command) { s += "⌘" }
            return s
        }
    }

    var displayString: String {
        modifiers.displaySymbols + KeyCodeNaming.name(for: keyCode)
    }
}

enum HotKeyIdentifier: UInt32 {
    case activateInterface = 1
    case fullScreen = 2
    case region = 3
    case window = 4
}

/// Owns the Carbon event handler and all currently-registered hotkeys.
/// Swift-only apps still have to drop into Carbon for global shortcuts
/// because there is no public AppKit/SwiftUI API for system-wide hotkeys
/// that works without Accessibility permission.
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()
    private init() { installEventHandlerIfNeeded() }

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var callbacks: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false

    func register(shortcut: KeyboardShortcutSpec, identifier: HotKeyIdentifier, action: @escaping () -> Void) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_5253) /* 'CLRS' */, id: identifier.rawValue)

        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers.carbonFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else { return }
        hotKeyRefs[identifier.rawValue] = ref
        callbacks[identifier.rawValue] = action
    }

    func unregisterAll() {
        hotKeyRefs.values.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        callbacks.removeAll()
    }

    private func installEventHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.callbacks[hotKeyID.id]?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}

/// Human-readable names for the small set of virtual key codes this app cares
/// about (Space, digits, letters). Falls back to "Key <code>" for anything
/// not explicitly listed.
enum KeyCodeNaming {
    private static let names: [UInt32: String] = [
        49: "Space", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K", 37: "L",
        46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W",
        7: "X", 16: "Y", 6: "Z"
    ]

    static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
