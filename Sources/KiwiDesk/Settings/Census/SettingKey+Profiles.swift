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
            // Dead while a stored profile is being edited
            // (bindings are global). The separate-Spaces arm
            // retired with #888: a binding now names one event
            // in every display mode — the main display's
            // Desktop N activating — so the rows stay live
            // there.
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
        case .presetsLayouts:
            // The preview sheet's opener (#859). **No gate**, and
            // it is the only row on this card without one: the
            // sheet writes nothing, and a user whose screen count
            // does not match — the state that greys Apply — is the
            // one who most needs to see what a preset contains.
            //
            // A census row even though it mutates nothing, which
            // no other `(action)` case can say. The precedent is
            // `(action) general.advanced.edit_lua`, whose
            // immediate effect is also opening a surface: the
            // census's unit is what a Settings surface OFFERS, not
            // what writes. Being in it is what gives the button a
            // search anchor and a label key every catalog must
            // carry (`SettingKeyLocaleTests`).
            //
            // `.atRest` for the same reason `presetsApply` is, and
            // it inherits that key's straddle: the instances in
            // the "For other setups" drawer sit behind a
            // disclosure while these describe the appliable group.
            return .row(.profiles, .presets, .atRest)
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
        case .isStarterSetup:
            return .none
        case .presetsApply:
            return .text("presets.apply")
        case .presetsLayouts:
            return .text("presets.layouts")
        }
    }
}
