import KiwiDeskCore

/// Reset escape hatches for SettingsModel (#634, #1096).
extension SettingsModel {
    /// Tier 1: discards saved multi-monitor snapshot.
    func discardSavedArrangement() {
        core.discardSavedArrangement()
    }

    /// Tier 2: resets core state and reloads freshly seeded configuration.
    func resetAllSettings() {
        core.resetAllSettings(trash: KiwiCore.moveToTrash)
        reload()
    }

    /// Resets default layer shortcuts to current install defaults (#1096).
    func resetShortcutsToDefaults() {
        guard
            let index = config.layers.firstIndex(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return }
        let shipped = shippedDefaults
        let orphanLua = orphanLuaInDefaultLayer
        let kept = config.layers[index].bindings.filter {
            Self.survivesReset(
                $0,
                against: shipped,
                orphans: orphanLua
            )
        }
        config.layers[index].bindings = shipped + kept
    }

    private var shippedDefaults: [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: config.spaces,
            resizeStep: Int(config.settings.resizeStep)
        )
    }

    /// Inactive Space shortcut Lua in default layer (#820, #92).
    private var orphanLuaInDefaultLayer: Set<String> {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return [] }
        return Set(
            OrphanedShortcuts.commands(
                bindings: layer.bindings,
                spaces: config.spaces
            )
            .map(\.lua)
        )
    }

    /// Count of default shortcuts restored by reset.
    var shortcutsTheResetWouldRestore: Int {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return 0 }
        let have = Set(
            layer.bindings.map { "\($0.combo)\u{1F}\($0.lua)" }
        )
        return shippedDefaults.filter {
            !have.contains("\($0.combo)\u{1F}\($0.lua)")
        }
        .count
    }

    /// True if default layer differs from shipped defaults.
    var hasDefaultsToRestore: Bool {
        shortcutsTheResetWouldRestore > 0
            || shortcutsTheResetWouldDiscard > 0
    }

    private static func survivesReset(
        _ row: KeyBinding,
        against shipped: [KeyBinding],
        orphans: Set<String>
    ) -> Bool {
        if shipped.contains(where: { $0.lua == row.lua }) {
            return false
        }
        if orphans.contains(row.lua) {
            return false
        }
        guard let combo = KeyCombo.parse(row.combo) else {
            return true
        }
        return !shipped.contains {
            KeyCombo.parse($0.combo) == combo
        }
    }

    /// Count of custom shortcuts displaced by restoring defaults.
    var shortcutsTheResetWouldDiscard: Int {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return 0 }
        let shipped = shippedDefaults
        let orphanLua = orphanLuaInDefaultLayer
        return layer.bindings.filter { row in
            if shipped.contains(where: { $0.lua == row.lua }) {
                return false
            }
            if orphanLua.contains(row.lua) { return false }
            guard let combo = KeyCombo.parse(row.combo) else {
                return false
            }
            return shipped.contains {
                KeyCombo.parse($0.combo) == combo
            }
        }
        .count
    }
}
