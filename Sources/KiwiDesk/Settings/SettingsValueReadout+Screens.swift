import KiwiDeskCore

/// Screens settings diff readout generators.
extension SettingsValueReadout {
    static func screensRows(
        _ key: ScreensKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.screens(key)
        switch key {
        case .spacePins:
            return screensPinRows(
                census,
                old: old.spacePins,
                new: new.spacePins
            )
        case .mainSpaces:
            return screensMainRows(
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

    /// One row per re-pinned space, showing the stored
    /// `name:WxH` fingerprint verbatim: no fingerprint→name
    /// helper exists, and a parser here would be a second copy
    /// of the fingerprint grammar.
    private static func screensPinRows(
        _ census: SettingKey,
        old: [SpaceID: String],
        new: [SpaceID: String]
    ) -> [SettingsDiffRow] {
        let base = L("diff.label.space_pin", "Screen pin")
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

    /// Diff rows for spaces joining or leaving the follows-main set.
    private static func screensMainRows(
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
