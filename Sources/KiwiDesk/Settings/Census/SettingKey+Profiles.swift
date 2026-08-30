/// Profiles: saved-profile actions, flags, desktop bindings.

enum ProfilesKey: String, CaseIterable, Hashable {
    case profileBindings = "config.profileBindings[n]"
    case profilesLoad = "(action) profiles.load"
    case profilesDelete = "(action) profiles.delete"
    case profilesRename = "(action) profiles.rename"
    case isDefault = "profile.isDefault"
    case isStarterSetup = "profile.isStarterSetup"
    case presetsApply = "(action) presets.apply"
    case presetsLayouts = "(action) presets.layouts"
}

extension ProfilesKey {
    var placement: SettingPlacement {
        switch self {
        case .profileBindings:
            // Inactive while editing a stored profile (#888).
            return .row(
                .profiles,
                .profilesPerMacOSSpace,
                .showMore,
                gate: .runtime(.editingStoredProfile)
            )
        case .profilesLoad, .profilesDelete, .profilesRename, .isDefault:
            return .row(.profiles, .savedProfiles, .atRest)
        case .isStarterSetup:
            return .luaOnly
        case .presetsApply:
            // Greys on screen count mismatch or stored profile edit (#678).
            return .row(
                .profiles,
                .presets,
                .atRest,
                gate: .runtimeAnyOf([
                    .screenCountMismatch,
                    .editingStoredProfile,
                ])
            )
        case .presetsLayouts:
            // Ungated preview sheet opener (#859, SettingKeyLocaleTests).
            return .row(.profiles, .presets, .atRest)
        }
    }
}

extension ProfilesKey {
    var text: SettingRowText {
        switch self {
        case .profileBindings:
            return .dynamic
        case .profilesLoad:
            return .text("profiles.load")
        case .profilesDelete:
            return .text("profiles.delete.help")
        case .profilesRename:
            return .text("profiles.rename", help: "profiles.rename.help")
        case .isDefault:
            return .text("profiles.make_default")
        case .isStarterSetup:
            return .none
        case .presetsApply:
            return .text("presets.apply")
        case .presetsLayouts:
            return .text("presets.layouts")
        }
    }
}
