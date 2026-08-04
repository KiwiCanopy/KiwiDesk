import KiwiDeskCore

/// One instance a Profiles census key expands into (#678 Phase 3,
/// turn 13a).
///
/// Every container in this area draws a row per live thing rather
/// than a row per setting, so the instance carries the thing's
/// identity — which is what a guard can compare, and what set
/// equality over `SettingKey` alone cannot see.
enum ProfilesRowInstance: Hashable {
    /// One saved profile, by name.
    case profile(String)
    /// One native macOS Desktop, by Mission Control number.
    case desktop(Int)
    /// One built-in preset, by its stable English
    /// `StandardLayout.name` (never the localized display name —
    /// identity must not move with the GUI language).
    case preset(String)
}

/// Expands a Profiles census key into the rows it renders (#678
/// Phase 3, turn 13a).
///
/// The census records settings, not rows: `profilesLoad` is one
/// case and puts one button on every saved profile's row,
/// `profileBindings` one case and one row per Desktop. That is
/// the same asymmetry the Shortcuts area met first, and it needs
/// the same second seam — `ProfilesRowOrder` answers *where does
/// this key sit*, this answers *what does it draw*, and
/// `ProfilesCensusRenderTests` pins each against the census
/// independently.
///
/// The switch is exhaustive over `ProfilesKey` on purpose: a key
/// added to the census fails to compile here until it is given an
/// expansion, which is a stronger net than the render guard alone.
///
/// A key with no rows of its own returns `nil` — and WHICH keys
/// may answer it is enumerated in `ProfilesCensusRenderTests`
/// rather than counted here, because a renderer reading
/// `rows(for:) ?? []` cannot tell a key that never draws from one
/// whose rows disappeared.
struct ProfilesFamilyRows {
    /// The saved profiles, in the list's display order.
    let profiles: [String]
    /// The native Desktops the bindings card lists — every
    /// present desktop plus any number already bound.
    let desktops: [Int]
    /// The presets the area offers, in catalog order.
    let presets: [StandardLayout]

    func rows(for key: SettingKey) -> [ProfilesRowInstance]? {
        guard case .profiles(let family) = key else { return nil }
        return rows(for: family)
    }

    private func rows(
        for family: ProfilesKey
    ) -> [ProfilesRowInstance]? {
        switch family {
        case .profilesLoad, .profilesDelete, .profilesRename,
            .isDefault:
            return profiles.map(ProfilesRowInstance.profile)
        case .profileBindings:
            return desktops.map(ProfilesRowInstance.desktop)
        case .presetsApply:
            return presets.map {
                ProfilesRowInstance.preset($0.name)
            }
        case .isStarterLadder:
            // Lua-only: a profile identity flag with no Settings
            // surface at all (`SettingPlacement.luaOnly`), so it
            // draws nothing here and never will.
            return nil
        }
    }
}
