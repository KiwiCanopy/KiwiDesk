/// The settings census (#678, spec 4f): one case per row of
/// the reviewed placement table (see `SettingPlacement.swift`
/// for the contract). `id` is the verbatim table row key —
/// machine-checked identity for the `settings.*` / `config.*`
/// slices (the model-parity guard parses those); the other
/// prefixes (`UserDefaults.`, `(action) `, …) are census
/// prose, held stable by convention only.

enum SettingKey: Hashable, CaseIterable {
    case appBar(AppBarKey)
    case appRules(AppRulesKey)
    case behaviour(BehaviourKey)
    case borders(BordersKey)
    case colours(ColoursKey)
    case gaps(GapsKey)
    case general(GeneralKey)
    case layout(LayoutKey)
    case layoutAppBar(LayoutAppBarKey)
    case monitors(MonitorsKey)
    case profiles(ProfilesKey)
    case shortcuts(ShortcutsKey)
    case spaceBar(SpaceBarKey)
    case spaces(SpacesKey)

    static var allCases: [SettingKey] {
        AppBarKey.allCases.map(Self.appBar)
            + AppRulesKey.allCases.map(Self.appRules)
            + BehaviourKey.allCases.map(Self.behaviour)
            + BordersKey.allCases.map(Self.borders)
            + ColoursKey.allCases.map(Self.colours)
            + GapsKey.allCases.map(Self.gaps)
            + GeneralKey.allCases.map(Self.general)
            + LayoutKey.allCases.map(Self.layout)
            + LayoutAppBarKey.allCases.map(Self.layoutAppBar)
            + MonitorsKey.allCases.map(Self.monitors)
            + ProfilesKey.allCases.map(Self.profiles)
            + ShortcutsKey.allCases.map(Self.shortcuts)
            + SpaceBarKey.allCases.map(Self.spaceBar)
            + SpacesKey.allCases.map(Self.spaces)
    }

    /// The verbatim census row (CSV key) —
    /// the catalog's stable identity.
    var id: String {
        switch self {
        case .appBar(let k): return k.rawValue
        case .appRules(let k): return k.rawValue
        case .behaviour(let k): return k.rawValue
        case .borders(let k): return k.rawValue
        case .colours(let k): return k.rawValue
        case .gaps(let k): return k.rawValue
        case .general(let k): return k.rawValue
        case .layout(let k): return k.rawValue
        case .layoutAppBar(let k): return k.rawValue
        case .monitors(let k): return k.rawValue
        case .profiles(let k): return k.rawValue
        case .shortcuts(let k): return k.rawValue
        case .spaceBar(let k): return k.rawValue
        case .spaces(let k): return k.rawValue
        }
    }

    var placement: SettingPlacement {
        switch self {
        case .appBar(let k): return k.placement
        case .appRules(let k): return k.placement
        case .behaviour(let k): return k.placement
        case .borders(let k): return k.placement
        case .colours(let k): return k.placement
        case .gaps(let k): return k.placement
        case .general(let k): return k.placement
        case .layout(let k): return k.placement
        case .layoutAppBar(let k): return k.placement
        case .monitors(let k): return k.placement
        case .profiles(let k): return k.placement
        case .shortcuts(let k): return k.placement
        case .spaceBar(let k): return k.placement
        case .spaces(let k): return k.placement
        }
    }

    var text: SettingRowText {
        switch self {
        case .appBar(let k): return k.text
        case .appRules(let k): return k.text
        case .behaviour(let k): return k.text
        case .borders(let k): return k.text
        case .colours(let k): return k.text
        case .gaps(let k): return k.text
        case .general(let k): return k.text
        case .layout(let k): return k.text
        case .layoutAppBar(let k): return k.text
        case .monitors(let k): return k.text
        case .profiles(let k): return k.text
        case .shortcuts(let k): return k.text
        case .spaceBar(let k): return k.text
        case .spaces(let k): return k.text
        }
    }
}
