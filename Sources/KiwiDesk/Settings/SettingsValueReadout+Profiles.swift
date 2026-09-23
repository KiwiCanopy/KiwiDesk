import Foundation
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
            .profilesAddScreenSetup,
            .isDefault, .isStarterSetup, .presetsApply,
            .presetsLayouts:
            // no model path — never booked by the diff
            return []
        }
    }

    /// One row per re-bound Desktop, valued by its entries — one
    /// per screen count and scope, listed (#1436, #1609), a scoped
    /// one naming its screens — with the unset dash for a binding
    /// that appeared or was cleared. Diffed by ENTRY, so a scope
    /// moved under an unchanged name still owes its row.
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
        func names(_ binding: DesktopBinding?) -> String {
            guard let binding, !binding.entries.isEmpty else {
                return unset
            }
            return LocalizedList.join(binding.entries.map(entryName))
        }
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0]?.entries != new[$0]?.entries }
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
                old: names(old[key]),
                new: names(new[key])
            )
        }
    }

    /// An entry as the diff names it: the profile, and for a
    /// scoped one the screens of its setup by name.
    private static func entryName(_ entry: DesktopBinding.Entry) -> String {
        guard let setup = entry.setup else { return entry.profile }
        return L(
            "diff.value.binding_setup",
            "%1$@ on %2$@",
            entry.profile,
            LocalizedList.join(
                setup.map { Display.fingerprintParts($0).name }
            )
        )
    }
}
