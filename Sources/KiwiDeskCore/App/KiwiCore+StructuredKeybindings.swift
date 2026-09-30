import Foundation

/// Prepared structured keybindings waiting for one atomic
/// `KeybindingManager` swap. Lua refs are minted before the
/// running table changes, so an apply never exposes a
/// half-built layer set.
struct PreparedKeybindings {
    var refs: [String: [KeyCombo: Int32]]
    var icons: [String: String]
    var registeredLayers: [KeyLayer]
}

extension KiwiCore {
    /// Resolves the base + profile tiers, prepares every Lua
    /// callback, then replaces all layers in one batch — the one
    /// door to the running structured table, called only with
    /// saved layers (`ShortcutsApplyOnSaveTests`). Regular
    /// config/profile applies reset to default; a rule write's
    /// refresh keeps the running layer.
    func applyStructuredKeybindings(
        layers base: [KeyLayer],
        profile: KeyLayerOverride?,
        lua: LuaInterpreter,
        preferredLayer: String = KeybindingManager.defaultLayer
    ) {
        let resolved = ConfigResolver.resolvedLayers(
            base: base,
            profile: profile
        )
        let prepared = prepareKeybindings(
            resolved,
            lua: lua
        )
        keys.replaceLayers(
            prepared.refs,
            icons: prepared.icons,
            preferredLayer: preferredLayer
        )
        appliedStructuredLayers = prepared.registeredLayers
    }

    /// Compiles every representable, assigned binding without
    /// touching the running table. Invalid combos and compile
    /// errors are logged and skipped per binding.
    private func prepareKeybindings(
        _ layers: [KeyLayer],
        lua: LuaInterpreter
    ) -> PreparedKeybindings {
        var refs: [String: [KeyCombo: Int32]] = [:]
        var icons: [String: String] = [:]
        var registeredLayers: [KeyLayer] = []

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
        }
        return PreparedKeybindings(
            refs: refs,
            icons: icons,
            registeredLayers: registeredLayers
        )
    }

    private func prepare(
        layer: KeyLayer,
        lua: LuaInterpreter
    ) -> (
        refs: [KeyCombo: Int32],
        bindings: [KeyBinding]
    ) {
        var entries:
            [KeyCombo: (index: Int, binding: KeyBinding, ref: Int32)] = [:]

        for (index, binding) in layer.bindings.enumerated()
        where !binding.combo.isEmpty {
            guard let combo = KeyCombo.parse(binding.combo)
            else {
                onLog(
                    "structured: invalid combo "
                        + "'\(binding.combo)'"
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
            bindings: ordered.map(\.value.binding)
        )
    }
}
