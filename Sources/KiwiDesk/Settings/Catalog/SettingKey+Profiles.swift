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
            // TODO(#678) gatedBy
            return .row(.profiles, .profilesPerMacOSSpace, .showMore)
        case .profilesLoad, .profilesDelete, .profilesRename, .isDefault:
            return .row(.profiles, .savedProfiles, .atRest)
        case .isStarterLadder:
            return .luaOnly
        case .presetsApply:
            // TODO(#678) gatedBy
            return .row(.profiles, .savedProfiles, .atRest)
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
