import Foundation

/// Abstraction over Carbon hotkey registration for test isolation.
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

/// Modal keybinding manager with named layers and hold-to-glide
/// support (#1056, #1082).
@MainActor
public final class KeybindingManager {
    public static let defaultLayer = "default"

    public var lua: LuaInterpreter?
    public var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Layer change callback for GUI indicators.
    public var onLayerChange: @MainActor (String) -> Void = {
        _ in
    }

    public private(set) var currentLayer = defaultLayer
    /// True while executing Lua hotkey handler (#184).
    public private(set) var isFiring = false
    /// Combos rejected during activation (#123).
    public internal(set) var activationFailures: Set<KeyCombo> =
        []
    private var layers: [String: [KeyCombo: Int32]] = [:]
    private var layerIcons: [String: String] = [:]
    /// Live registrations mapped by id (#1056, #1082).
    var activeBindings: [UInt32: LiveBinding] = [:]

    struct LiveBinding {
        var ref: Int32
        var combo: KeyCombo
    }

    /// Box holding assigned registration id for handler closure (#1056).
    final class RegistrationBox {
        var id: UInt32?
    }

    /// Hold-to-glide engine (#1056, #1082).
    let holdGlide = HoldGlide()
    private var suspended = false
    let registrar: HotkeyRegistrar

    public init(
        registrar: HotkeyRegistrar = CarbonHotkeyCenter()
    ) {
        self.registrar = registrar
        wireHoldGlideChannels(registrar: registrar)
    }

    /// Bindings for specified layer name.
    public func bindings(
        for layer: String
    ) -> [KeyCombo: Int32] {
        layers[layer] ?? [:]
    }

    /// Defined layer names in stable order for GUI import (#4).
    public var definedLayers: [String] {
        let others = layers.keys
            .filter { $0 != Self.defaultLayer }
            .sorted()
        return [Self.defaultLayer] + others
    }

    /// Binds combo to Lua ref in default layer.
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

    /// Defines layer with given bindings and optional icon.
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

    public func icon(for layer: String) -> String? {
        layerIcons[layer]
    }

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

    /// Resets all layers and releases Lua references on config reload.
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

    /// Atomically replaces layers from structured config.
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

    /// True while hotkeys are suspended by Settings shortcut recorder (#213).
    public var isSuspended: Bool { suspended }

    /// Suspends hotkey registration during recorder capture (#213).
    public func suspend() {
        guard !suspended else { return }
        suspended = true
        deactivate()
    }

    /// Resumes hotkeys after recorder capture (#213).
    public func resume() {
        guard suspended else { return }
        suspended = false
        activate(currentLayer)
    }

    func fire(ref: Int32, combo: KeyCombo) {
        guard let lua else { return }
        let wasFiring = isFiring
        isFiring = true
        defer { isFiring = wasFiring }
        if case .failure(let error) = lua.call(ref: ref) {
            onLog("keybinding disabled: \(error)")
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
