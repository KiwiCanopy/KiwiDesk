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
        case .focusDir, .screenLast, .spaceStep, .spaceHistoryStep,
            .goToSpace, .swapDir,
            .moveWindowToTrack, .swapWithTrack, .moveToSpace,
            .moveToSpaceFollow, .focusDesktop, .moveToDesktop,
            .moveToDesktopFollow, .layoutCycle, .viewPicker, .jumpToWindow,
            .growWidth, .shrinkWidth, .growHeight, .shrinkHeight, .resetSizes,
            .maximize,
            .toggleFloating, .toggleKiwiVision, .toggleLens,
            .toggleSpaceBar, .toggleAppBar,
            .toggleSticky, .pocket, .pocketWindow,
            .showShortcuts,
            .openSettings, .switchToLayer, .openApplications,
            .advanced, .`import`, .restoreDefaults:
            return []
        // App-wide, written at once, never in the draft (#1741).
        case .modeCue, .desktopCue, .hyperKey,
            .kiwiHubNavigationKeys, .modifierSides:
            return []
        // A layer's profiles are no config field: the checklist's own
        // rows carry them (`layerDiffRows`, #2022).
        case .layersReach:
            return []
        case .scrollPan, .scrollLongSwipes, .scrollStepDistance,
            .scrollNaturalTrackpad, .scrollNaturalMouse, .scrollSpaceStep:
            return scrollGestureRows(key, old: old, new: new)
        case .shortcutBase:
            return [
                .change(
                    census,
                    label: ShortcutBaseWords.title,
                    old: ShortcutBaseWords.glyphs(old.shortcutBase),
                    new: ShortcutBaseWords.glyphs(new.shortcutBase)
                )
            ]
        case .spaceHistory:
            return [
                .change(
                    census,
                    label: SpaceHistoryWords.title,
                    old: SpaceHistoryWords.value(old.spaceHistory),
                    new: SpaceHistoryWords.value(new.spaceHistory)
                )
            ]
        case .focusWrap:
            return [
                .change(
                    census,
                    label: FocusWrapWords.title,
                    old: FocusWrapWords.value(old.focusWrap),
                    new: FocusWrapWords.value(new.focusWrap)
                )
            ]
        case .pocketEdge:
            return [
                .change(
                    census,
                    label: SettingsCatalog.shortcuts.pocketEdge.text,
                    old: PocketGroup.edgeName(
                        old.settings.pocketStyle.edge
                    ),
                    new: PocketGroup.edgeName(
                        new.settings.pocketStyle.edge
                    )
                )
            ]
        case .pocketPosition:
            return [
                .change(
                    census,
                    label: SettingsCatalog.shortcuts.pocketPosition.text,
                    old: pocketPercent(old),
                    new: pocketPercent(new)
                )
            ]
        case .modeCycle:
            return [
                .change(
                    census,
                    label: LayoutCycleWords.title,
                    old: LayoutCycleWords.readout(old.modeCycle),
                    new: LayoutCycleWords.readout(new.modeCycle)
                )
            ]
        }
    }

    private static func shortcutsLayerRows(
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        // The rows the base switch moved are narrated by its own
        // row (#2460): compare against the old draft switched the
        // same way, so only the user's other edits list here.
        var old = old
        if old.shortcutBase != new.shortcutBase {
            ShortcutBaseSwitch.apply(new.shortcutBase, to: &old)
        }
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
                    labels: labels,
                    config: new
                )
            } else {
                var row = SettingsDiffRow.note(
                    census,
                    instance: "layer+" + layer.name,
                    label: instanceLabel(layerBase, layer.name),
                    note: addedNote
                )
                // The whole layer, its saved name resolved there.
                row.revert = .layer(stored: nil, page: layer.name)
                rows.append(row)
            }
        }
        for layer in old.layers
        where newByName[layer.name] == nil {
            var row = SettingsDiffRow.note(
                census,
                instance: "layer-" + layer.name,
                label: instanceLabel(layerBase, layer.name),
                note: removedNote
            )
            row.revert = .layer(stored: layer.name, page: nil)
            rows.append(row)
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
        labels: [String: String],
        config: GuiConfig
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
                        config: config,
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
                        config: config,
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
                    config: config,
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
        config: GuiConfig,
        old: String,
        new: String
    ) -> SettingsDiffRow {
        let action = shortcutsBindingLabel(
            binding,
            labels: labels,
            config: config
        )
        let label =
            layer.isDefault
            ? action : instanceLabel(layer.name, action)
        var row = SettingsDiffRow.change(
            census,
            instance: layer.name + "/" + binding.lua + "/"
                + instance,
            label: label,
            old: old,
            new: new
        )
        row.subject = ReachSubject(
            family: .key,
            key: RuleReachTable<String>.keyID(
                layer: layer.name,
                lua: binding.lua
            )
        )
        row.revert = .binding(layer: layer.name, lua: binding.lua)
        return row
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

    private static func pocketPercent(_ config: GuiConfig) -> String {
        percent(Double(config.settings.pocketStyle.position) / 100)
    }
}
