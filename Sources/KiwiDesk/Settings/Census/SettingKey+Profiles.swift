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
            // Dead while a stored profile is being edited
            // (bindings are global), AND dead while displays
            // have separate Spaces (every display has its own
            // Desktop 1). One slot, two arms — the tag names
            // the disjunction rather than half of it, and
            // `ProfilesGates` tells the two apart.
            return .row(
                .profiles,
                .profilesPerMacOSSpace,
                .showMore,
                gate: .runtimeAnyOf([
                    .editingStoredProfile,
                    .displaysHaveSeparateSpaces,
                ])
            )
        case .profilesLoad, .profilesDelete, .profilesRename, .isDefault:
            return .row(.profiles, .savedProfiles, .atRest)
        case .isStarterLadder:
            return .luaOnly
        case .presetsApply:
            // Its own card since #678 turn 13a — "Start from a
            // preset" is a distinct offer from the saved list it
            // used to sit inside, and the redesign draws it as
            // one. Apply is greyed by the screen-count match;
            // `ProfilesGates` also answers the stored-profile
            // reason for the same row (one gate slot, two
            // reasons).
            //
            // `.atRest` describes the instances that MATTER: the
            // presets for the connected screen count, which is
            // the only group whose Apply can fire. The rest
            // render inside the "For other setups" drawer, so
            // this one key's instances straddle two tiers — the
            // first such key in the census. The tier follows the
            // appliable group deliberately: a search hit on a
            // preset should offer to apply it, and tiering the
            // key `.showMore` would describe the group nobody
            // can act on.
            return .row(
                .profiles,
                .presets,
                .atRest,
                gate: .runtimeAnyOf([
                    .screenCountMismatch,
                    .editingStoredProfile,
                ])
            )
        }
    }
}

extension ProfilesKey {
    var text: SettingRowText {
        switch self {
        case .profileBindings:
            // "Desktop %1$d" — per-instance rows, so dynamic.
            return .dynamic
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
