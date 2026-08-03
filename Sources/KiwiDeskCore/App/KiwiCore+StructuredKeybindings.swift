import Foundation

/// Prepared structured keybindings waiting for one atomic
/// `KeybindingManager` swap. Lua refs are minted before the
/// running table changes, so a recorder edit never exposes a
/// half-built layer set (#123 review).
struct PreparedKeybindings {
    struct Failure {
        let layer: String
        let binding: KeyBinding
    }

    var refs: [String: [KeyCombo: Int32]]
    var icons: [String: String]
    var registeredLayers: [KeyLayer]
    var failures: [Failure]

    @MainActor func release(using lua: LuaInterpreter) {
        for bindings in refs.values {
            for ref in bindings.values {
                lua.release(ref: ref)
            }
        }
    }
}

extension KiwiCore {
    /// Resolves the base + profile tiers, prepares every Lua
    /// callback, then replaces all layers in one batch. Regular
    /// config/profile applies reset to default; recorder-only
    /// entry points call the lower seam with their active layer.
    func applyStructuredKeybindings(
        layers base: [KeyLayer],
        profile: KeyLayerOverride?,
        lua: LuaInterpreter
    ) {
        let resolved = ConfigResolver.resolvedLayers(
            base: base,
            profile: profile
        )
        let prepared = prepareKeybindings(
            resolved,
            lua: lua
        )
        install(
            prepared,
            preferredLayer: KeybindingManager.defaultLayer
        )
    }

    /// Compiles every representable, assigned binding without
    /// touching the running table. Invalid combos and compile
    /// errors retain established per-binding skip semantics;
    /// failures remain identifiable so live recorder feedback
    /// never claims the target compiled.
    func prepareKeybindings(
        _ layers: [KeyLayer],
        lua: LuaInterpreter
    ) -> PreparedKeybindings {
        var refs: [String: [KeyCombo: Int32]] = [:]
        var icons: [String: String] = [:]
        var registeredLayers: [KeyLayer] = []
        var failures: [PreparedKeybindings.Failure] = []

        for layer in layers {
            let prepared = prepare(layer: layer, lua: lua)
            refs[layer.name] = prepared.refs
            if let icon = layer.icon, !icon.isEmpty {
                icons[layer.name] = icon
            }
            registeredLayers.append(
                KeyLayer(
                    name: layer.name,
                    icon: layer.icon,
                    bindings: prepared.bindings
                )
            )
            failures.append(contentsOf: prepared.failures)
        }
        return PreparedKeybindings(
            refs: refs,
            icons: icons,
            registeredLayers: registeredLayers,
            failures: failures
        )
    }

    func install(
        _ prepared: PreparedKeybindings,
        preferredLayer: String
    ) {
        keys.replaceLayers(
            prepared.refs,
            icons: prepared.icons,
            preferredLayer: preferredLayer
        )
        appliedStructuredLayers = prepared.registeredLayers
    }

    private func prepare(
        layer: KeyLayer,
        lua: LuaInterpreter
    ) -> (
        refs: [KeyCombo: Int32],
        bindings: [KeyBinding],
        failures: [PreparedKeybindings.Failure]
    ) {
        var entries:
            [KeyCombo: (index: Int, binding: KeyBinding, ref: Int32)] = [:]
        var failures: [PreparedKeybindings.Failure] = []

        for (index, binding) in layer.bindings.enumerated()
        where !binding.combo.isEmpty {
            guard let combo = KeyCombo.parse(binding.combo)
            else {
                onLog(
                    "structured: invalid combo "
                        + "'\(binding.combo)'"
                )
                failures.append(
                    .init(layer: layer.name, binding: binding)
                )
                continue
            }
            switch lua.makeFunction(body: binding.lua) {
            case .success(let ref):
                if let old = entries.updateValue(
                    (index, binding, ref),
                    forKey: combo
                ) {
                    // Duplicate combo: last wins. Its earlier
                    // prepared ref never reaches the manager.
                    lua.release(ref: old.ref)
                }
            case .failure(let error):
                onLog(
                    "structured: bind skipped "
                        + "[\(binding.combo)]: \(error)"
                )
                failures.append(
                    .init(layer: layer.name, binding: binding)
                )
            }
        }

        let ordered =
            entries
            .sorted { $0.value.index < $1.value.index }
        return (
            refs: Dictionary(
                uniqueKeysWithValues: ordered.map {
                    ($0.key, $0.value.ref)
                }
            ),
            bindings: ordered.map(\.value.binding),
            failures: failures
        )
    }
}
