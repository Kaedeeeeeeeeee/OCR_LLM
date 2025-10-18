import Foundation
#if os(macOS)
import AppKit
import Carbon

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: (() -> Void)?

    func registerDefault(shift: Bool, command: Bool, key: Key, handler: @escaping () -> Void) {
        unregisterAll()
        self.hotKeyHandler = handler

        var modifiers: UInt32 = 0
        if shift { modifiers |= UInt32(shiftKey) }
        if command { modifiers |= UInt32(cmdKey) }

        let hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: "QOCR".fourCharCodeValue)), id: 1)

        RegisterEventHotKey(UInt32(key.rawValue), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (next, event, userData) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == 1 {
                Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue().hotKeyHandler?()
            }
            return noErr
        }, 1, [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))], Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    func unregisterAll() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        hotKeyHandler = nil
    }

    enum Key: Int {
        case e = 14 // kVK_ANSI_E
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for scalar in self.unicodeScalars {
            if let val = scalar.properties.numericType { _ = val }
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}

#else
final class HotkeyManager {
    func registerDefault(shift: Bool, command: Bool, key: Key, handler: @escaping () -> Void) {}
    func unregisterAll() {}
    enum Key: Int { case e = 14 }
}
#endif
