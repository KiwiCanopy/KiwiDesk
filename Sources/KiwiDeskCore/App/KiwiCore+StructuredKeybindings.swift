import Foundation

/// Prepared structured keybindings waiting for one atomic
/// `KeybindingManager` swap. Lua refs are minted before the
/// running table changes, so an apply never exposes a
/// half-built layer set.
struct PreparedKeybindings {
    var refs: [String: [KeyCombo: Int32]]
    var icons: [String: String]
    var registeredLayers: [KeyLayer]
    var skipped: [InstalledKeybindings.Skipped]
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
        profile: Profile?,
        lua: LuaInterpreter,
        preferredLayer: String = KeybindingManager.defaultLayer
    ) {
        let resolved = ConfigResolver.resolvedLayers(
            base: base,
            profile: profile?.layers
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
        installedKeybindings = .structured(
            prepared.registeredLayers,
            profile: profile.map {
                .init(name: $0.name, layers: $0.layers)
            },
            skipped: prepared.skipped
        )
        reconcilePocketKeys()  // #2612
        syncDerivedIssues()
    }

    /// Compiles every representable, assigned binding without
    /// touching the running table. Invalid combos and compile
    /// errors are logged and skipped per binding, and each skip is
    /// kept for its Config Issue (#2574).
    private func prepareKeybindings(
        _ layers: [KeyLayer],
        lua: LuaInterpreter
    ) -> PreparedKeybindings {
        var refs: [String: [KeyCombo: Int32]] = [:]
        var icons: [String: String] = [:]
        var registeredLayers: [KeyLayer] = []
        var skipped: [InstalledKeybindings.Skipped] = []

        for layer in layers {
            let prepared = prepare(layer: layer, lua: lua)
            refs[layer.name] = prepared.refs
            skipped += prepared.skipped
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
            registeredLayers: registeredLayers,
            skipped: skipped
        )
    }

    private func prepare(
        layer: KeyLayer,
        lua: LuaInterpreter
    ) -> (
        refs: [KeyCombo: Int32],
        bindings: [KeyBinding],
        skipped: [InstalledKeybindings.Skipped]
    ) {
        var entries:
            [KeyCombo: (index: Int, binding: KeyBinding, ref: Int32)] = [:]
        // One issue per key, the last row winning as it does in
        // `entries`; a chord that does not parse is keyed as typed.
        var failed: [KeyCombo: (chord: String, reason: DeadShortcutReason)] =
            [:]
        var unparsed: [String: DeadShortcutReason] = [:]

        for (index, binding) in layer.bindings.enumerated()
        where !binding.combo.isEmpty {
            guard let combo = KeyCombo.parse(binding.combo)
            else {
                onLog(
                    "structured: invalid combo "
                        + "'\(binding.combo)'"
                )
                unparsed[binding.combo] = .invalidChord
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
                // A VM that never started is `luaVMUnavailable`'s.
                if case .runtime(let message) = error {
                    failed[combo] = (binding.combo, .luaError(message))
                }
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
            // A key another row installed still fires (#2574).
            skipped:
                (failed.filter { entries[$0.key] == nil }.values
                .map { ($0.chord, $0.reason) }
                + unparsed.map { ($0.key, $0.value) })
                .map {
                    .init(layer: layer.name, chord: $0.0, reason: $0.1)
                }
                .sorted { $0.chord < $1.chord }
        )
    }
}
