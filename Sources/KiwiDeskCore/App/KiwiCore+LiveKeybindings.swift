import Foundation

/// Which owner's bindings `keys` holds, recorded by the apply that
/// installed them — never re-read from `init.lua`, which can change
/// on disk without a reload (#2482).
enum InstalledKeybindings {
    case structured([KeyLayer])
    case lua(layers: [KeyLayer], unread: [String: [String]])
}

/// The structured bindings currently installed, for the
/// read-only shortcuts reference panel (#326).
public struct LiveKeybindingSnapshot: Sendable {
    let layers: [KeyLayer]
    let activeLayer: String
    let unread: [String: [String]]
    let luaOwned: Bool

    /// The resolved key modes currently installed. Under Lua
    /// ownership, each row's `lua` is its recovered body.
    public var keyLayers: [KeyLayer] { layers }
    /// The runtime-active mode's name.
    public var activeLayerName: String { activeLayer }
    /// Whether `init.lua` installed these bindings (#2482).
    public var isLuaOwned: Bool { luaOwned }
    /// The chords in `layer` whose action could not be read back
    /// from `init.lua` — a named handler, a C function. Lua-owned
    /// only; never a `KeyBinding`, so nothing can save one.
    public func unreadChords(in layer: String) -> [String] {
        unread[layer] ?? []
    }
}

extension KiwiCore {
    /// Captures the effective bindings currently installed, by the
    /// owner the last load applied. nil without a live VM.
    public func liveKeybindingSnapshot()
        -> LiveKeybindingSnapshot?
    {
        guard keys.lua != nil, let installed = installedKeybindings
        else { return nil }
        switch installed {
        case .structured(let layers):
            return LiveKeybindingSnapshot(
                layers: layers,
                activeLayer: keys.currentLayer,
                unread: [:],
                luaOwned: false
            )
        case .lua(let layers, let unread):
            return LiveKeybindingSnapshot(
                layers: layers,
                activeLayer: keys.currentLayer,
                unread: unread,
                luaOwned: true
            )
        }
    }

    /// Reads back the bodies `init.lua` just bound, once per load:
    /// the file read now is the one that ran (#2482).
    func captureLuaKeybindings(from lua: LuaInterpreter) {
        let captured = KeybindingImporter.capture(
            from: keys,
            interpreter: lua,
            readFile: { try? String(contentsOfFile: $0, encoding: .utf8) }
        )
        installedKeybindings = .lua(
            layers: captured.layers,
            unread: captured.unread
        )
    }

    /// Suspends every KiwiDesk Carbon hotkey while a Settings
    /// recorder is armed (#213), so pressing an existing shortcut
    /// to test it can't fire its action. Paired with
    /// `resumeHotkeysForRecording()` when capture ends. Suspend/
    /// resume round-trip the exact table, so both are safe no-ops
    /// when nothing is registered; system shortcuts are untouched.
    public func suspendHotkeysForRecording() {
        keys.suspend()
    }

    public func resumeHotkeysForRecording() {
        keys.resume()
    }
}
