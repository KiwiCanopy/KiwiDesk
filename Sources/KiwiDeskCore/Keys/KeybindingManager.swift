import Foundation

/// Abstraction over Carbon hotkey registration so the manager
/// is testable without touching the real event system.
@MainActor
public protocol HotkeyRegistrar: AnyObject {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32?
    func unregister(id: UInt32)
}

extension CarbonHotkeyCenter: HotkeyRegistrar {}

/// Modal keybindings (04_API_Contract §8): named modes hold
/// their own bindings; exactly one mode is active. The default
/// mode holds `KiwiDesk.bind(...)` registrations.
@MainActor
public final class KeybindingManager {
    public static let defaultMode = "default"

    public var lua: LuaInterpreter?
    public var onLog: @MainActor (String) -> Void = { _ in }
    /// GUI indicator hook (mode name).
    public var onModeChange: @MainActor (String) -> Void = {
        _ in
    }

    public private(set) var currentMode = defaultMode
    private var modes: [String: [KeyCombo: Int32]] = [:]
    /// Menu bar indicator per mode (SF Symbol name or emoji),
    /// set via `define_mode(name, bindings, { icon = ... })`.
    private var modeIcons: [String: String] = [:]
    private var activeIDs: [UInt32] = []
    private let registrar: HotkeyRegistrar

    public init(
        registrar: HotkeyRegistrar = CarbonHotkeyCenter()
    ) {
        self.registrar = registrar
    }

    /// Bindings of one mode (exposed for the GUI editor).
    public func bindings(
        for mode: String
    ) -> [KeyCombo: Int32] {
        modes[mode] ?? [:]
    }

    /// Every defined mode name, the default first and the rest
    /// sorted, so the GUI import (#4) can enumerate them in a
    /// stable order. The default is always present even with no
    /// bindings, matching the always-present GUI default mode.
    public var definedModes: [String] {
        let others = modes.keys
            .filter { $0 != Self.defaultMode }
            .sorted()
        return [Self.defaultMode] + others
    }

    // MARK: - Registration (from Lua)

    /// `KiwiDesk.bind(combo, fn)` — default mode.
    public func bind(_ combo: KeyCombo, ref: Int32) {
        modes[Self.defaultMode, default: [:]][combo] = ref
        if currentMode == Self.defaultMode {
            activate(Self.defaultMode)
        }
    }

    /// `KiwiDesk.define_mode(name, { key = fn, ... }, opts)`.
    public func defineMode(
        _ name: String,
        bindings: [KeyCombo: Int32],
        icon: String? = nil
    ) {
        modes[name] = bindings
        if let icon, !icon.isEmpty {
            modeIcons[name] = icon
        } else {
            modeIcons[name] = nil
        }
        if currentMode == name {
            activate(name)
        }
    }

    /// The menu bar indicator for a mode, if one was set.
    public func icon(for mode: String) -> String? {
        modeIcons[mode]
    }

    /// `KiwiDesk.switch_mode(name)`.
    public func switchMode(_ name: String) {
        guard name == Self.defaultMode || modes[name] != nil
        else {
            onLog("switch_mode: unknown mode '\(name)'")
            return
        }
        currentMode = name
        activate(name)
        onModeChange(name)
    }

    /// Clears everything (config reload).
    public func reset() {
        deactivate()
        if let lua {
            for bindings in modes.values {
                for ref in bindings.values {
                    lua.release(ref: ref)
                }
            }
        }
        modes = [:]
        modeIcons = [:]
        currentMode = Self.defaultMode
    }

    // MARK: - Hotkey activation

    private func deactivate() {
        for id in activeIDs {
            registrar.unregister(id: id)
        }
        activeIDs = []
    }

    private func activate(_ mode: String) {
        deactivate()
        for (combo, ref) in modes[mode] ?? [:] {
            let id = registrar.register(
                keyCode: combo.keyCode,
                modifiers: combo.modifiers
            ) { [weak self] in
                self?.fire(ref: ref, combo: combo)
            }
            if let id {
                activeIDs.append(id)
            } else {
                onLog(
                    "keybinding conflict: could not "
                        + "register a shortcut in mode "
                        + "'\(mode)'"
                )
            }
        }
    }

    private func fire(ref: Int32, combo: KeyCombo) {
        guard let lua else { return }
        if case .failure(let error) = lua.call(ref: ref) {
            onLog("keybinding disabled: \(error)")
            // Disable the faulty callback (sandbox rules).
            for (mode, var bindings) in modes {
                if bindings[combo] == ref {
                    bindings[combo] = nil
                    modes[mode] = bindings
                }
            }
            lua.release(ref: ref)
            activate(currentMode)
        }
    }
}
