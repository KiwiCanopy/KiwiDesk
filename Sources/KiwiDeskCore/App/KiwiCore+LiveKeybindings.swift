import Foundation

/// Which owner's bindings `keys` holds, recorded by the apply that
/// installed them — never re-read from `init.lua`, which can change
/// on disk without a reload (#2482).
/// A structured install keeps the profile tier it resolved over —
/// its name and its override, nothing else — so an issue about one
/// of its rows names the file that holds it (#2544), and the rows
/// it could not install, so each is a Config Issue (#2574).
enum InstalledKeybindings {
    struct ProfileTier: Sendable {
        var name: String
        let layers: KeyLayerOverride?
    }

    /// A row the install skipped: its layer, chord and why.
    struct Skipped: Sendable, Equatable {
        let layer: String
        let chord: String
        let reason: DeadShortcutReason
    }

    case structured(
        [KeyLayer],
        profile: ProfileTier?,
        skipped: [Skipped]
    )
    case lua(layers: [KeyLayer], unread: [String: [UnreadChord]])
}

/// The structured bindings currently installed, for the
/// read-only shortcuts reference panel (#326).
public struct LiveKeybindingSnapshot: Sendable {
    let layers: [KeyLayer]
    let activeLayer: String
    let unread: [String: [UnreadChord]]
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
    public func unreadChords(in layer: String) -> [UnreadChord] {
        unread[layer] ?? []
    }

    /// What every installed binding says of itself, by layer and
    /// chord — read rows and unread chords alike (#2544).
    func metaByChord()
        -> [(layer: String, chord: String, meta: KeyBindingMeta)]
    {
        layers.flatMap { layer in
            layer.bindings.map { (layer.name, $0.combo, $0.meta) }
                + unreadChords(in: layer.name).map {
                    (layer.name, $0.chord, $0.meta)
                }
        }
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
        case .structured(let layers, _, _):
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

    /// The live settings and Spaces a Lua-owned snapshot's rows
    /// are filed against: live state only, never `gui.json`, which
    /// such a config does not run, and never a re-read of
    /// `init.lua` (#2482).
    public func liveShortcutContext() -> GuiConfig {
        var config = GuiConfig()
        overlayLiveProfileState(&config)
        return config
    }

    /// Reads back the bodies `init.lua` just bound, once per load:
    /// the file read now is the one that ran (#2482).
    func captureLuaKeybindings(from lua: LuaInterpreter) {
        let captured = KeybindingImporter.capture(
            from: keys,
            interpreter: lua,
            readFile: KeybindingImporter.readSource
        )
        installedKeybindings = .lua(
            layers: captured.layers,
            unread: captured.unread
        )
        syncDerivedIssues()
    }

    /// Follows a rename of the profile the structured install
    /// resolved over, so an issue names the file by its new name.
    func renameInstalledProfile(_ old: String, to new: String) {
        guard
            case .structured(let layers, var tier?, let skipped) =
                installedKeybindings,
            tier.name == old
        else { return }
        tier.name = new
        installedKeybindings = .structured(
            layers,
            profile: tier,
            skipped: skipped
        )
        syncDerivedIssues()
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
