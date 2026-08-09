import KiwiDeskCore

/// Monitors rows: the space→monitor pin map and the Main-role
/// set. The banner, the orphan-clear action and the read-only
/// fingerprints drawer name no model path, so the diff never
/// books them.
extension SettingsValueReadout {
    static func monitorsRows(
        _ key: MonitorsKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.monitors(key)
        switch key {
        case .spacePins:
            return monitorsPinRows(
                census,
                old: old.spacePins,
                new: new.spacePins
            )
        case .mainSpaces:
            return monitorsMainRows(
                census,
                old: old.mainSpaces,
                new: new.mainSpaces
            )
        case .orphanPinClear, .fingerprints,
            .placementUnavailable:
            // no model path — never booked by the diff
            return []
        }
    }

    /// One row per re-pinned space. Values are the stored
    /// `name:WxH` fingerprint — the same string the area's
    /// fingerprints drawer shows; no fingerprint→display-name
    /// helper exists to resolve a prettier one from a bare
    /// string, and inventing a parser here would be a second
    /// copy of the fingerprint grammar.
    private static func monitorsPinRows(
        _ census: SettingKey,
        old: [SpaceID: String],
        new: [SpaceID: String]
    ) -> [SettingsDiffRow] {
        let base = L("diff.label.space_pin", "Monitor pin")
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            .change(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                old: old[space] ?? unset,
                new: new[space] ?? unset
            )
        }
    }

    /// A structural note per space that joined or left the
    /// Main role, labelled by the census's own follows-main
    /// text plus the space's name.
    private static func monitorsMainRows(
        _ census: SettingKey,
        old: Set<SpaceID>,
        new: Set<SpaceID>
    ) -> [SettingsDiffRow] {
        let base = label(for: census)
        let touched = old.symmetricDifference(new)
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            .note(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                note: new.contains(space)
                    ? addedNote : removedNote
            )
        }
    }
}
