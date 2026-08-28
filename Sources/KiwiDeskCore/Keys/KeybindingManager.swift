import Foundation

/// Abstraction over Carbon hotkey registration so the manager
/// is testable without touching the real event system.
///
/// An implementor never fires the handler of a registration
/// that FAILED (`register` returned nil) — the hold-to-repeat
/// press path leans on it (`RegistrationBox` carries a nil id
/// for exactly that handler), and Carbon holds it for free
/// since a failed registration installs nothing.
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

/// Modal keybindings: named layers hold
/// their own bindings; exactly one layer is active. The default
/// layer holds `KiwiDesk.bind(...)` registrations.
@MainActor
public final class KeybindingManager {
    public static let defaultLayer = "default"

    public var lua: LuaInterpreter?
    public var onLog: @MainActor (String) -> Void = CoreLog.write
    /// GUI indicator hook (layer name).
    public var onLayerChange: @MainActor (String) -> Void = {
        _ in
    }

    public private(set) var currentLayer = defaultLayer
    /// True while a hotkey's Lua callback runs (#184): commands
    /// executing inside a fire are keyboard-interactive, so
    /// failure cues (the unsupported-resize beep) key off this —
    /// the same command from CLI/IPC or init.lua stays silent.
    /// Deliberately synchronous-only: work a hotkey body defers
    /// (an `ExecLauncher` completion, a `Task`) runs with the
    /// flag off and never cues. Save/restore (not set/clear) in
    /// `fire`, so a callback that pumps a nested run loop and
    /// delivers a second fire can't clear the outer fire's flag.
    public private(set) var isFiring = false
    /// Combos the system declined in the most recent
    /// activation (`RegisterEventHotKey` returned no id — e.g.
    /// a reserved system shortcut). Rebuilt on every
    /// activation; the GUI's live-apply (#123) reads it to
    /// branch its feedback caption ("Active now" vs "the
    /// system didn't grant it").
    public private(set) var activationFailures: Set<KeyCombo> =
        []
    private var layers: [String: [KeyCombo: Int32]] = [:]
    /// Menu bar indicator per layer (SF Symbol name or emoji),
    /// set via `define_layer(name, bindings, { icon = ... })`.
    private var layerIcons: [String: String] = [:]
    /// The live registrations by id — the ONE home for "what is
    /// registered right now": `deactivate`'s unregister loop and
    /// the hold-to-repeat engine's re-fire and release routing
    /// (#1056) both read it. Written only by
    /// `activate`/`deactivate`; a second id list beside it would
    /// be two homes for one fact, drifting in opposite failure
    /// modes (a leaked live chord vs a tick against a dead id).
    private(set) var activeBindings: [UInt32: LiveBinding] = [:]

    /// One live registration: the Lua ref and the combo it is
    /// registered under.
    struct LiveBinding {
        var ref: Int32
        var combo: KeyCombo
    }

    /// Hands a registration handler its own id (#1056): the
    /// closure is built before `register` returns the id, so
    /// the id travels through this box, filled immediately
    /// after. Nil only for a handler whose registration failed
    /// — which `HotkeyRegistrar`'s contract says never fires.
    final class RegistrationBox {
        var id: UInt32?
    }
    /// Hold-to-repeat (#1056). Internal so `KiwiCore.execute`
    /// and the size-limit cues can feed it through the
    /// `noteCommand` / `noteResizeRefusal` passthroughs below.
    let holdRepeat = HoldRepeat()
    /// True while a Settings recorder is armed (#213): all our
    /// hotkeys are unregistered so testing an existing shortcut
    /// mid-capture can't fire its action. Table/layer edits still
    /// apply but skip registration until `resume()`.
    private var suspended = false
    private let registrar: HotkeyRegistrar

    public init(
        registrar: HotkeyRegistrar = CarbonHotkeyCenter()
    ) {
        self.registrar = registrar
        wireHoldRepeat(registrar: registrar)
    }

    /// Bindings of one layer (exposed for the GUI editor).
    public func bindings(
        for layer: String
    ) -> [KeyCombo: Int32] {
        layers[layer] ?? [:]
    }

    /// Every defined layer name, the default first and the rest
    /// sorted, so the GUI import (#4) can enumerate them in a
    /// stable order. The default is always present even with no
    /// bindings, matching the always-present GUI default layer.
    public var definedLayers: [String] {
        let others = layers.keys
            .filter { $0 != Self.defaultLayer }
            .sorted()
        return [Self.defaultLayer] + others
    }

    // MARK: - Registration (from Lua)

    /// `KiwiDesk.bind(combo, fn)` — default layer. A rebound
    /// combo's displaced ref is released (registry slots must
    /// not leak between resets).
    public func bind(_ combo: KeyCombo, ref: Int32) {
        let old = layers[Self.defaultLayer, default: [:]]
            .updateValue(ref, forKey: combo)
        if let old, old != ref {
            lua?.release(ref: old)
        }
        if currentLayer == Self.defaultLayer {
            activate(Self.defaultLayer)
        }
    }

    /// `KiwiDesk.define_layer(name, { key = fn, ... }, opts)`.
    /// Redefining an existing layer releases the displaced
    /// refs — a duplicate layer name in hand-edited config must
    /// not leak registry slots until the next reload.
    public func defineLayer(
        _ name: String,
        bindings: [KeyCombo: Int32],
        icon: String? = nil
    ) {
        if let lua, let old = layers[name] {
            for ref in old.values
            where bindings.values.contains(ref) == false {
                lua.release(ref: ref)
            }
        }
        layers[name] = bindings
        if let icon, !icon.isEmpty {
            layerIcons[name] = icon
        } else {
            layerIcons[name] = nil
        }
        if currentLayer == name {
            activate(name)
        }
    }

    /// The menu bar indicator for a layer, if one was set.
    public func icon(for layer: String) -> String? {
        layerIcons[layer]
    }

    /// `KiwiDesk.switch_layer(name)`.
    public func switchLayer(_ name: String) {
        guard name == Self.defaultLayer || layers[name] != nil
        else {
            onLog("switch_layer: unknown layer '\(name)'")
            return
        }
        currentLayer = name
        activate(name)
        onLayerChange(name)
    }

    /// Clears everything (config reload / profile apply).
    /// Falling back to the default layer notifies
    /// `onLayerChange` — the menu-bar indicator must not keep
    /// showing a layer whose bindings just went away.
    public func reset() {
        deactivate()
        if let lua {
            for bindings in layers.values {
                for ref in bindings.values {
                    lua.release(ref: ref)
                }
            }
        }
        layers = [:]
        layerIcons = [:]
        let changed = currentLayer != Self.defaultLayer
        currentLayer = Self.defaultLayer
        if changed {
            onLayerChange(Self.defaultLayer)
        }
    }

    /// Atomically replaces every layer prepared by the
    /// structured-config bridge. Preparation happens before
    /// this call, so the old table remains callable until one
    /// swap; Carbon registration then runs once for the chosen
    /// layer instead of once per growing default-layer prefix.
    ///
    /// `preferredLayer` preserves a recorder session's active
    /// layer when it still exists. Profile/config applies pass
    /// `default`, retaining their settled reset semantics.
    func replaceLayers(
        _ replacements: [String: [KeyCombo: Int32]],
        icons: [String: String],
        preferredLayer: String
    ) {
        let oldLayers = layers
        let oldCurrent = currentLayer

        deactivate()
        layers = replacements
        if layers[Self.defaultLayer] == nil {
            layers[Self.defaultLayer] = [:]
        }
        layerIcons = icons

        if preferredLayer == Self.defaultLayer
            || layers[preferredLayer] != nil
        {
            currentLayer = preferredLayer
        } else {
            currentLayer = Self.defaultLayer
        }

        if let lua {
            for bindings in oldLayers.values {
                for ref in bindings.values {
                    lua.release(ref: ref)
                }
            }
        }
        activate(currentLayer)
        if currentLayer != oldCurrent {
            onLayerChange(currentLayer)
        }
    }

    // MARK: - Recorder suspension (#213)

    /// True while suspended by an armed Settings recorder.
    public var isSuspended: Bool { suspended }

    /// Unregisters every hotkey while a Settings recorder is
    /// armed, so pressing an existing KiwiDesk shortcut to test
    /// it can't trigger its action. Idempotent. Only touches our
    /// own Carbon registrations — macOS/system shortcuts are the
    /// OS's and stay live.
    public func suspend() {
        guard !suspended else { return }
        suspended = true
        deactivate()
    }

    /// Restores the hotkeys suspended by `suspend()`, registering
    /// whatever layer is current now — a layer/table change made
    /// during suspension is honored. Idempotent.
    public func resume() {
        guard suspended else { return }
        suspended = false
        activate(currentLayer)
    }

    // MARK: - Hotkey activation

    private func deactivate() {
        // The ids are about to vanish, so no release can ever
        // arrive to stop a live repeat — end it here (#1056).
        holdRepeat.cancelRun()
        for id in activeBindings.keys {
            registrar.unregister(id: id)
        }
        activeBindings = [:]
    }

    private func activate(_ layer: String) {
        deactivate()
        activationFailures = []
        // A recorder is armed: keep the table current but
        // register nothing, so testing a shortcut can't fire.
        guard !suspended else { return }
        for (combo, ref) in layers[layer] ?? [:] {
            // The handler carries its own registration id via
            // the box, filled the moment `register` returns —
            // never re-derived after the fire, where the Lua
            // body may have rebuilt the table and minted fresh
            // ids for the same ref+combo (#1056 review).
            let box = RegistrationBox()
            let id = registrar.register(
                keyCode: combo.keyCode,
                modifiers: combo.modifiers
            ) { [weak self] in
                self?.pressFire(
                    ref: ref,
                    combo: combo,
                    id: box.id
                )
            }
            if let id {
                box.id = id
                activeBindings[id] = LiveBinding(
                    ref: ref,
                    combo: combo
                )
            } else {
                activationFailures.insert(combo)
                onLog(
                    "keybinding conflict: could not "
                        + "register a shortcut in layer "
                        + "'\(layer)'"
                )
            }
        }
    }

    func fire(ref: Int32, combo: KeyCombo) {
        guard let lua else { return }
        let wasFiring = isFiring
        isFiring = true
        defer { isFiring = wasFiring }
        if case .failure(let error) = lua.call(ref: ref) {
            onLog("keybinding disabled: \(error)")
            // Disable the faulty callback (sandbox rules).
            for (layer, var bindings) in layers {
                if bindings[combo] == ref {
                    bindings[combo] = nil
                    layers[layer] = bindings
                }
            }
            lua.release(ref: ref)
            activate(currentLayer)
        }
    }
}
