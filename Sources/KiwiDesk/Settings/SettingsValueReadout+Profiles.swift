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

    /// One row per re-bound native Space, valued by profile
    /// name with the unset dash for a binding that appeared or
    /// was cleared.
    private static func profilesBindingRows(
        _ census: SettingKey,
        old: [Int: String],
        new: [Int: String]
    ) -> [SettingsDiffRow] {
        let base = L(
            "diff.label.profile_binding",
            "Profile binding"
        )
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted()
        return touched.map { number in
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
                instance: String(number),
                label: instanceLabel(base, desktop),
                old: old[number] ?? unset,
                new: new[number] ?? unset
            )
        }
    }
}
