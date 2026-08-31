import KiwiDeskCore

/// Shortcuts area diff row generation (`GuiConfig`, `KeyLayer`, #23).
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
            .moveToSpaceFollow, .focusDesktop, .moveToDesktop,
            .moveToDesktopFollow, .growWidth, .shrinkWidth,
            .growHeight, .shrinkHeight, .toggleFloating,
            .toggleSticky, .toggleDisplaySticky, .showShortcuts,
            .openSettings, .switchToLayer, .openApplications,
            .advanced, .`import`, .restoreDefaults:
            return []
        }
    }

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

    /// Generates per-binding diff rows for key layer
    /// (`KeyLayer`, `KeyBinding`).
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

    /// Computes unmatched binding pairs across old and new binding sets.
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
