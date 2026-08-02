/// Profiles: saved-profile actions, flags, desktop bindings.

enum ProfilesKey: String, CaseIterable, Hashable {
    case profileBindings = "config.profileBindings[n]"
    case profilesLoad = "(action) profiles.load"
    case profilesDelete = "(action) profiles.delete"
    case profilesRename = "(action) profiles.rename"
    case isDefault = "profile.isDefault"
    case isStarterLadder = "profile.isStarterLadder"
    case presetsApply = "(action) presets.apply"
}

extension ProfilesKey {
    var placement: SettingPlacement {
        switch self {
        case .profileBindings:
            // Desktop bindings are global — dead while a
            // stored profile is being edited.
            return .row(
                .profiles,
                .profilesPerMacOSSpace,
                .showMore,
                gate: .runtime(.editingStoredProfile)
            )
        case .profilesLoad, .profilesDelete, .profilesRename, .isDefault:
            return .row(.profiles, .savedProfiles, .atRest)
        case .isStarterLadder:
            return .luaOnly
        case .presetsApply:
            return .row(
                .profiles,
                .savedProfiles,
                .atRest,
                gate: .runtime(.screenCountMismatch)
            )
        }
    }
}

extension ProfilesKey {
    var text: SettingRowText {
        switch self {
        case .profileBindings:
            return .text("native_spaces.desktop")
        case .profilesLoad:
            return .text("profiles.load")
        case .profilesDelete:
            return .text("profiles.delete.help")
        case .profilesRename:
            return .text("profiles.rename", help: "profiles.rename.help")
        case .isDefault:
            return .text("profiles.make_default")
        case .isStarterLadder:
            return .none
        case .presetsApply:
            return .text("presets.apply")
        }
    }
}
