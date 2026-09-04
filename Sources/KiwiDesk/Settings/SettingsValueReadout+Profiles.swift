import KiwiDeskCore

/// Profiles-area diff readout generators.
extension SettingsValueReadout {
    static func profilesRows(
        _ key: ProfilesKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.profiles(key)
        switch key {
        case .profileBindings:
            return profilesBindingRows(
                census,
                old: old.profileBindings,
                new: new.profileBindings
            )
        case .profilesLoad, .profilesDelete, .profilesRename,
            .isDefault, .isStarterSetup, .presetsApply,
            .presetsLayouts:
            // no model path — never booked by the diff
            return []
        }
    }

    /// One row per re-bound Desktop, valued by profile name with
    /// the unset dash for a binding that appeared or was cleared.
    ///
    /// Diffed by KEY and NARRATED by the number each record was
    /// last seen at (#1147) — a key is not a name any reader has.
    /// The census INSTANCE is the key, not the number: a dormant
    /// record and a live Desktop can both project one number, and
    /// two rows sharing an instance would collapse in the diff.
    private static func profilesBindingRows(
        _ census: SettingKey,
        old: [DesktopKey: DesktopBinding],
        new: [DesktopKey: DesktopBinding]
    ) -> [SettingsDiffRow] {
        let base = L(
            "diff.label.profile_binding",
            "Profile binding"
        )
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0]?.profile != new[$0]?.profile }
            .map { key in
                (key, new[key]?.desktop ?? old[key]?.desktop ?? 0)
            }
            .sorted { $0.1 < $1.1 }
        return touched.map { key, number in
            // The area's own per-instance frame, reused so the
            // diff names a native Space exactly the way the
            // Profiles rows do (#768: macOS's are Desktops).
            let desktop = L(
                "desktops.desktop",
                "Desktop %1$d",
                number
            )
            return .change(
                census,
                instance: key.stored,
                label: instanceLabel(base, desktop),
                old: old[key]?.profile ?? unset,
                new: new[key]?.profile ?? unset
            )
        }
    }
}
