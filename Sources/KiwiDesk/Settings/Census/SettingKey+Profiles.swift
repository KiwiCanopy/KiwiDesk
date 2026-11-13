/// Profiles: saved-profile actions, flags, desktop bindings.

enum ProfilesKey: String, CaseIterable, Hashable {
    case profileBindings = "config.profileBindings[n]"
    case profilesLoad = "(action) profiles.load"
    case profilesDelete = "(action) profiles.delete"
    case profilesRename = "(action) profiles.rename"
    case profilesAddScreenSetup = "(action) profiles.sets.move"
    case isDefault = "profile.isDefault"
    case isStarterSetup = "profile.isStarterSetup"
}

extension ProfilesKey {
    var placement: SettingPlacement {
        switch self {
        case .profileBindings:
            // Live under every edit target — bindings are a
            // global table — and inert only where the stored
            // profile's Save has no sidecar to file one (#1392).
            return .row(
                .profiles,
                .profilesPerMacOSSpace,
                .showMore,
                gate: .runtime(.noBindingStore)
            )
        case .profilesLoad, .profilesDelete, .profilesRename, .isDefault,
            .profilesAddScreenSetup:
            return .row(.profiles, .savedProfiles, .atRest)
        case .isStarterSetup:
            return .luaOnly
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
            return .text("profiles.make_default.one")
        case .profilesAddScreenSetup:
            return .text("profiles.sets.move.help")
        case .isStarterSetup:
            return .none
        }
    }
}
