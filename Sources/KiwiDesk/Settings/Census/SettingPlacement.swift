/// The placement vocabulary of the settings census (#678,
/// spec 4f). Every setting KiwiDesk has is one `SettingKey`
/// case, and each case resolves to its placement and text
/// through exhaustive switches — an unplaced setting is a
/// compile error, not a bug report. During the coexistence
/// phase (old GUI still renders) the census is what the 4f
/// guards hold against the model and the locale catalogs;
/// rendering from it starts with the Bars area (Phase 2).

/// The two Settings modes: "Simple" / "Power User" (owner
/// 2026-08-04), user-facing and wire alike. The marketing
/// site's slider keeps its own "Nerd" flair — a different
/// surface, never harmonized either way
/// (`docs/localization-naming.md` owns the pair's policy). The
/// design doc's "Easy/Advanced" is spec-internal shorthand and
/// never appears in code or copy; the word "mode" itself stays
/// reserved for this pair and for layout modes.
enum SettingsMode: String, CaseIterable, Hashable {
    case simple
    case powerUser
}

/// A Home-level area card in the redesigned Settings window.
enum SettingsArea: CaseIterable, Hashable {
    case gapsAndBorders
    case layoutDefaults
    case shortcuts
    case coloursAndMotion
    case bars
    case advancedColours
    case spacesAndLayouts
    case behaviour
    case monitors
    case profiles
    case appRules
    case general

    /// The mode an area first appears in — mode depth is per
    /// area, never per row. `.simple` areas render in both
    /// modes; `.powerUser` areas exist only while Power User
    /// mode is on (it adds surface, never expands it).
    var minimumMode: SettingsMode {
        switch self {
        case .advancedColours, .behaviour, .monitors:
            return .powerUser
        // Layout Defaults is `.simple` (owner ruling
        // 2026-08-04), against the digest's own Advanced
        // placement. The argument that moved it: these are
        // parameters people LEARN the app by playing with —
        // change a split ratio, watch the windows move — so
        // withholding them teaches nothing and hides the thing
        // a tiling window manager is for. Its size (the largest
        // card in the app) was the case for Advanced, and size
        // is a reason to organise a card well, not to hide it.
        //
        // The per-space OVERRIDE stays gated (`SpaceOverrideOffer`)
        // — editing one layout's defaults is the feature; editing
        // them per space is bookkeeping about exceptions.
        case .layoutDefaults, .gapsAndBorders, .shortcuts,
            .coloursAndMotion, .bars, .spacesAndLayouts,
            .profiles, .appRules, .general:
            return .simple
        }
    }

    /// `minimumMode` with the one COMPUTED promotion (turn 9):
    /// Monitors joins Simple whenever two or more displays are
    /// connected — a multi-monitor desk needs space placement in
    /// its first week. Computed at read, never stored: writing
    /// the promotion back would strand it after a disconnect.
    func effectiveMinimumMode(
        displayCount: Int
    ) -> SettingsMode {
        if self == .monitors, displayCount >= 2 {
            return .simple
        }
        return minimumMode
    }
}

/// How deep a setting sits. "Show more" rows and Power-User-only cards
/// are different things — never conflate them in copy or code:
/// `.showMore` is a
/// row-level disclosure; mode depth is
/// `SettingsArea.minimumMode`.
enum SettingTier: Hashable {
    /// Visible at rest in its container.
    case atRest
    /// Not visible at rest, one interaction away: behind the
    /// container's "Show more" disclosure, or — where the
    /// container's affordance is a menu rather than a drawer —
    /// in that menu. The palette actions are the second kind
    /// (Rename / Export / Delete, on a saved palette's context
    /// menu), and the definition is stated HERE rather than
    /// only at that use site: the mode-mechanics phase renders
    /// from this enum, and a renderer trusting the narrower
    /// wording would put those three in a drawer.
    case showMore
    /// Surfaces without disclosure the moment its gate allows.
    ///
    /// This is the tier that carries **config presence expands
    /// the Simple surface**: anything that already EXISTS in the
    /// user's config — a layer, an imported binding, an override
    /// — shows in both modes and enhances the simple one. Simple
    /// withholds only the OFFER to create, never an existing
    /// thing. So an `.immediate` row is at rest once its gate
    /// says the thing exists, and behind the offer's disclosure
    /// before that; it is NOT a `.showMore` row, and reading it
    /// as one hides a user's own configuration from them.
    case immediate
    /// Reachable only from Lua (`init.lua`), by design.
    case luaOnly
    /// App-internal storage (picker recents) — no surface.
    case internalOnly
    /// Lives outside the Settings window (onboarding wizard).
    case outsideSettings
}

/// How a row is titled: a stable `L()` key, or text the GUI
/// composes at runtime — space names, per-instance keybinding
/// rows (their family keys carry positional specifiers and are
/// only ever formatted per instance), the orientation-swapped
/// slot-size label.
enum SettingLabel: Hashable {
    case key(String)
    case dynamic
}

/// The localized text a row carries — label, optional grey
/// caption, optional `?` help popover. Key-only on purpose: the
/// English lives at the live views' `L()` call sites, which is
/// what `scripts/extract-keys` scans, so the census never
/// becomes a second authoring surface for `en.json`. Before a
/// Phase 2+ change deletes a view, the renderer must author
/// each key through a scanner-recognized `L(key, english)`
/// shape in the same change, or the key is pruned from every
/// locale (`SettingKeyLocaleTests` reds at that moment). Tiers
/// the GUI never renders (`.luaOnly`, `.internalOnly`,
/// `.outsideSettings`) carry `.none`.
struct SettingRowText: Hashable {
    var label: SettingLabel?
    var captionKey: String?
    var helpKey: String?

    static let none = SettingRowText(
        label: nil,
        captionKey: nil,
        helpKey: nil
    )
    static let dynamic = SettingRowText(
        label: .dynamic,
        captionKey: nil,
        helpKey: nil
    )
    static func text(
        _ labelKey: String,
        caption: String? = nil,
        help: String? = nil
    ) -> SettingRowText {
        SettingRowText(
            label: .key(labelKey),
            captionKey: caption,
            helpKey: help
        )
    }
}

/// Where one setting lives (item 12): area card, container,
/// tier, and — for a row that greys behind something — its
/// gate, composing with `SettingsContainer.gate`.
/// `area`/`container` are nil exactly for the tiers that have
/// no Settings surface.
struct SettingPlacement: Hashable {
    var area: SettingsArea?
    var container: SettingsContainer?
    var tier: SettingTier
    var gate: SettingGate?
    /// True for the rare row the live wiring deliberately
    /// keeps OUTSIDE its container's block gate (the icon
    /// source picker also feeds the ⌃⌥K panel's Apps band, so
    /// it stays live while the App Bar editor greys).
    var exemptFromContainerGate = false

    static let luaOnly = SettingPlacement(
        area: nil,
        container: nil,
        tier: .luaOnly,
        gate: nil
    )
    static let internalOnly = SettingPlacement(
        area: nil,
        container: nil,
        tier: .internalOnly,
        gate: nil
    )
    static let outsideSettings = SettingPlacement(
        area: nil,
        container: nil,
        tier: .outsideSettings,
        gate: nil
    )
    static func row(
        _ area: SettingsArea,
        _ container: SettingsContainer,
        _ tier: SettingTier,
        gate: SettingGate? = nil,
        exemptFromContainerGate: Bool = false
    ) -> SettingPlacement {
        SettingPlacement(
            area: area,
            container: container,
            tier: tier,
            gate: gate,
            exemptFromContainerGate: exemptFromContainerGate
        )
    }
}
