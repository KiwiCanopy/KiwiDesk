import KiwiDeskCore

/// Shortcuts-area rows. Every binding lives inside
/// `config.layers`, so the one bookable key expands to
/// per-binding narration — "Focus down · ⌥N → ⌥J" through the
/// recorder's own glyph pipeline (#23), with the unset dash on
/// an added/removed binding's empty side — plus a structural
/// note per layer that appeared or vanished. The
/// `keybinding.*` family keys name no model path of their own:
/// the diff attribution books their changes under
/// `config.layers`, which is the `.layers` arm here.
extension SettingsValueReadout {
    static func shortcutsRows(
        _ key: ShortcutsKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.shortcuts(key)
        switch key {
        case .layers:
            return shortcutsLayerRows(census, old: old, new: new)
        case .layersIcon:
            return shortcutsIconRows(census, old: old, new: new)
        case .focusDir, .goToSpace, .swapDir,
            .moveWindowToTrack, .swapWithTrack, .moveToSpace,
            .moveToSpaceFollow, .growWidth, .shrinkWidth,
            .growHeight, .shrinkHeight, .toggleFloating,
            .toggleSticky, .toggleDisplaySticky, .showShortcuts,
            .switchToLayer, .openApplications, .advanced,
            .`import`:
            // no model path — never booked by the diff (these
            // families' bindings book under `config.layers`).
            return []
        }
    }

    // MARK: - config.layers

    private static func shortcutsLayerRows(
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let labels = shortcutsActionLabels(old: old, new: new)
        let oldByName = shortcutsLayersByName(old.layers)
        let newByName = shortcutsLayersByName(new.layers)
        let layerBase = L("diff.label.layer", "Layer")
        var rows: [SettingsDiffRow] = []
        for layer in new.layers {
            if let previous = oldByName[layer.name] {
                rows += shortcutsBindingRows(
                    census,
                    layer: layer,
                    old: previous.bindings,
                    labels: labels
                )
            } else {
                rows.append(
                    .note(
                        census,
                        instance: "layer+" + layer.name,
                        label: instanceLabel(
                            layerBase,
                            layer.name
                        ),
                        note: addedNote
                    )
                )
            }
        }
        for layer in old.layers
        where newByName[layer.name] == nil {
            rows.append(
                .note(
                    census,
                    instance: "layer-" + layer.name,
                    label: instanceLabel(layerBase, layer.name),
                    note: removedNote
                )
            )
        }
        // A layer reorder or a metadata-only binding edit
        // (kind/label upgraded by import) moves no combo, so
        // nothing above narrates it — one edited note keeps the
        // key total for the readout totality guard.
        if rows.isEmpty, old.layers != new.layers {
            rows.append(
                .note(
                    census,
                    label: L("diff.label.layers", "Layers"),
                    note: editedNote
                )
            )
        }
        return rows
    }

    /// Per-binding rows for a layer present on both sides:
    /// exact-equal rows drop out first, the leftovers pair by
    /// Lua action (a re-recorded combo), and the unpaired rest
    /// narrate as bound/unbound against the unset dash.
    private static func shortcutsBindingRows(
        _ census: SettingKey,
        layer: KeyLayer,
        old: [KeyBinding],
        labels: [String: String]
    ) -> [SettingsDiffRow] {
        let (removed, added) = shortcutsUnmatched(
            old: old,
            new: layer.bindings
        )
        var additions = added
        var rows: [SettingsDiffRow] = []
        var unbound = -1
        for binding in removed {
            if let index = additions.firstIndex(where: {
                $0.lua == binding.lua
            }) {
                let successor = additions.remove(at: index)
                guard successor.combo != binding.combo else {
                    // kind/label-only upgrade — no combo moved.
                    continue
                }
                rows.append(
                    shortcutsRow(
                        census,
                        layer: layer,
                        binding: successor,
                        instance: binding.combo + ">"
                            + successor.combo,
                        labels: labels,
                        old: shortcutsCombo(binding.combo),
                        new: shortcutsCombo(successor.combo)
                    )
                )
            } else {
                // The enumeration index rides the instance so
                // DUPLICATE bound/unbound bindings still mint
                // distinct row ids inside one ForEach.
                unbound += 1
                rows.append(
                    shortcutsRow(
                        census,
                        layer: layer,
                        binding: binding,
                        instance: "-" + binding.combo
                            + "#\(unbound)",
                        labels: labels,
                        old: shortcutsCombo(binding.combo),
                        new: unset
                    )
                )
            }
        }
        for (index, binding) in additions.enumerated() {
            rows.append(
                shortcutsRow(
                    census,
                    layer: layer,
                    binding: binding,
                    instance: "+" + binding.combo + "#\(index)",
                    labels: labels,
                    old: unset,
                    new: shortcutsCombo(binding.combo)
                )
            )
        }
        return rows
    }

    private static func shortcutsRow(
        _ census: SettingKey,
        layer: KeyLayer,
        binding: KeyBinding,
        instance: String,
        labels: [String: String],
        old: String,
        new: String
    ) -> SettingsDiffRow {
        let action = shortcutsBindingLabel(
            binding,
            labels: labels
        )
        // The default layer is the whole surface at rest, so
        // only a named layer prefixes its rows.
        let label =
            layer.isDefault
            ? action : instanceLabel(layer.name, action)
        return .change(
            census,
            instance: layer.name + "/" + binding.lua + "/"
                + instance,
            label: label,
            old: old,
            new: new
        )
    }

    /// Counted set difference under full binding equality:
    /// (old-only, new-only) once every exactly-equal pair is
    /// consumed — by count, so twin bindings of one action
    /// (vim keys + arrows) each match once.
    private static func shortcutsUnmatched(
        old: [KeyBinding],
        new: [KeyBinding]
    ) -> ([KeyBinding], [KeyBinding]) {
        var remaining = new
        var removed: [KeyBinding] = []
        for binding in old {
            if let index = remaining.firstIndex(of: binding) {
                remaining.remove(at: index)
            } else {
                removed.append(binding)
            }
        }
        return (removed, remaining)
    }

    // MARK: - config.layers[].icon

    private static func shortcutsIconRows(
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let oldByName = shortcutsLayersByName(old.layers)
        var rows: [SettingsDiffRow] = []
        for layer in new.layers {
            guard let previous = oldByName[layer.name],
                previous.icon != layer.icon
            else { continue }
            rows.append(
                .change(
                    census,
                    instance: layer.name,
                    label: instanceLabel(
                        label(for: census),
                        layer.name
                    ),
                    old: previous.icon ?? unset,
                    new: layer.icon ?? unset
                )
            )
        }
        return rows
    }

    private static func shortcutsLayersByName(
        _ layers: [KeyLayer]
    ) -> [String: KeyLayer] {
        Dictionary(
            layers.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
