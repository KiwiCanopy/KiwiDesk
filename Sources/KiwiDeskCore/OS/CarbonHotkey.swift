import AppKit
import Carbon.HIToolbox

// VERIFICATION NOTE — macOS 27+:
// The Carbon hotkey API (`RegisterEventHotKey`) is ancient but
// has no modern replacement that works without the "Input
// Monitoring" permission. Re-check on EVERY new macOS release
// (27 and later) that:
//   1. RegisterEventHotKey still registers and fires.
//   2. No new permission prompt appears on first registration.
//   3. GetEventDispatcherTarget still delivers on the main
//      run loop.
// If Carbon breaks, the fallback is a CGEventTap, which DOES
// require Input Monitoring — a UX regression to surface
// prominently in release notes.

/// Modifier mask for Carbon hotkeys.
public struct HotkeyModifiers: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = Self(rawValue: UInt32(cmdKey))
    public static let option = Self(rawValue: UInt32(optionKey))
    public static let control = Self(
        rawValue: UInt32(controlKey)
    )
    public static let shift = Self(rawValue: UInt32(shiftKey))
}

/// C entry point for Carbon hotkey events. Fires on the main
/// event dispatcher.
private func hotkeyCallback(
    _ handler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ refcon: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let refcon else { return noErr }
    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else { return status }
    let center = Unmanaged<CarbonHotkeyCenter>
        .fromOpaque(refcon)
        .takeUnretainedValue()
    MainActor.assumeIsolated {
        center.dispatch(id: hotkeyID.id)
    }
    return noErr
}

/// Registers system-wide keyboard shortcuts via the Carbon API.
///
/// Shortcuts are intercepted by the system directly — KiwiDesk
/// never needs the global "Input Monitoring" (keylogger)
/// permission. Event taps are reserved for mouse drag tracking
/// only (see AGENTS.md guardrails).
@MainActor
public final class CarbonHotkeyCenter {
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    /// Four-char code "KIWI" tagging our hotkey registrations.
    private static let signature: OSType = {
        var code: OSType = 0
        for byte in "KIWI".utf8 {
            code = (code << 8) + OSType(byte)
        }
        return code
    }()

    public init() {}

    /// Registers a hotkey; returns its ID, or nil on failure
    /// (e.g. the combination is taken by the system).
    public func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        installHandlerIfNeeded()
        let id = nextID
        let hotkeyID = EventHotKeyID(
            signature: Self.signature,
            id: id
        )
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers.rawValue,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return nil }
        nextID += 1
        handlers[id] = handler
        refs[id] = ref
        return id
    }

    public func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlers[id] = nil
    }

    public func unregisterAll() {
        for id in Array(refs.keys) {
            unregister(id: id)
        }
    }

    fileprivate func dispatch(id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            hotkeyCallback,
            1,
            &eventType,
            refcon,
            &eventHandler
        )
    }
}
