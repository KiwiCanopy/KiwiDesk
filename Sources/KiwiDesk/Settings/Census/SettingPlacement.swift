/// The placement vocabulary of the settings census (#678,
/// spec 4f). Every setting KiwiDesk has is one `SettingKey`
/// case, and each case resolves to its placement and text
/// through exhaustive switches — an unplaced setting is a
/// compile error, not a bug report. During the coexistence
/// phase (old GUI still renders) the census is what the 4f
/// guards hold against the model and the locale catalogs;
/// rendering from it starts with the Bars area (Phase 2).

/// The two Settings modes, in the shipped (site-slider)
/// vocabulary: user-facing "Simple" / "Nerd". The design doc's
/// "Easy/Advanced" is spec-internal shorthand and never appears
/// in code or copy; the word "mode" itself stays reserved for
/// this pair and for layout modes.
enum SettingsMode: CaseIterable, Hashable {
    case simple
    case nerd
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
    /// modes; `.nerd` areas exist only while Nerd mode is on
    /// (Nerd adds surface, never expands it).
    var minimumMode: SettingsMode {
        switch self {
        case .layoutDefaults, .advancedColours, .behaviour,
            .monitors:
            return .nerd
        case .gapsAndBorders, .shortcuts, .coloursAndMotion,
            .bars, .spacesAndLayouts, .profiles, .appRules,
            .general:
            return .simple
        }
    }
}

/// How deep a setting sits. "Show more" rows and nerd-only cards
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

/// A runtime condition a row greys — or, for the table's
/// CONDITIONAL presence rows, surfaces — on that is not itself
/// a setting. The tag names the condition; the wiring's help
/// string stays the authority for the on-screen sentence
/// (why-you-cannot is always inline, item 19).
enum SettingRuntimeGate: Hashable {
    /// The gaps master slider reads "mixed" while the per-edge
    /// values differ.
    case perEdgeValuesDiffer
    /// A stored profile is being edited, so a global setting
    /// this profile may never override is dead (switch to Live).
    case editingStoredProfile
    /// macOS's "Displays have separate Spaces" is on with more
    /// than one display attached, so every display has its own
    /// Desktop 1 and a Desktop binding names no single event.
    case displaysHaveSeparateSpaces
    /// Presets apply only when the connected screen count
    /// matches the preset's.
    case screenCountMismatch
    /// The login item follows `SMAppService` status — the
    /// setter is guarded, the control greys (#342).
    case loginItemServiceStatus
    /// Crash-restart is the LaunchAgent, whose RunAtLoad and
    /// KeepAlive are one unit — so it is dead unless KiwiDesk
    /// also starts at login (#678 item 16). Greying says so;
    /// `AutoStartLevel.level(openAtLogin:restartOnCrash:)` is
    /// what actually refuses the pair.
    case autoStartLoginOff
    /// The per-space reset action is dead while the space has
    /// no overrides.
    case spaceHasNoOverrides
    /// macOS Reduce Motion greys the animations card.
    case reduceMotion
    /// The orphaned-pins card exists only while a space is
    /// pinned to a disconnected monitor.
    case orphanPinsExist
    /// A stored profile is being edited AND its monitors are not
    /// attached — one slot, so this tag carries both arms, like
    /// `paletteGlowPairing` and `luaImportAvailable` below. There
    /// are then no display frames to draw the Monitors picture
    /// from, so the condition surfaces the not-connected banner
    /// and withholds the cards it stands in for
    /// (`MonitorsGates` resolves both sides).
    case monitorsDisconnected
    /// The neon "Pair with Glow" link shows only for palettes
    /// that carry the glow pairing (#578) — and only while
    /// Glow itself is off (`borderGlow` is the setting half of
    /// this condition; one gate slot per row, so the runtime
    /// tag carries the whole conjunction).
    case paletteGlowPairing
    /// The import row shows only while `init.lua` holds
    /// bindings the GUI can adopt AND the LIVE config is the
    /// edit target — one slot, so this tag carries both arms,
    /// the not-editing-a-stored-profile half included.
    case luaImportAvailable
    /// The config defines a layer beyond `default`. Gates the
    /// Layers card's `.immediate` tier: with layers configured
    /// the card is a user's own setup and shows at rest; with
    /// only `default` it is purely the offer to create one.
    case layersExist
    /// Liquid Glass is offered only where it can render
    /// (macOS 26+) — hidden, never greyed, matching the OS
    /// capability gate (#390); the `#available` check itself
    /// belongs to the renderer.
    case liquidGlassUnavailable
}

/// What greys a surfaced row (the placement table's GATED
/// rows). `.setting` / `.anyOf` name the surfaced rows whose
/// values decide the grey — the exact predicate (resolved
/// override chains, value comparisons) lives with the wiring,
/// and gates on resolved values name every surfaced owner
/// (#406: gate on RESOLVED, not global). `.runtime` names a
/// condition that is not itself a setting, and `.runtimeAnyOf`
/// names SEVERAL such conditions where a row dies for any of
/// them — so a multi-arm predicate is spelled out in the census
/// rather than hidden behind one tag standing for the whole
/// disjunction.
///
/// That distinction is load-bearing: a tag named for the row's
/// own OUTCOME ("this control is unavailable") records nothing a
/// reader could not see from the greyed row itself, and leaves
/// the predicate knowable only inside the area's resolver. Two
/// such tags existed for one commit; `.runtimeAnyOf` replaced
/// them, and with them a hand-kept register of which tags were
/// secretly compound. The remaining CONJUNCTIONS
/// (`paletteGlowPairing`, `luaImportAvailable`,
/// `monitorsDisconnected`) each state both arms in their own
/// docstring — `allOf` stays unbuilt because a conjunction has
/// no per-arm sentence to render: a row dead for both reasons
/// says one thing, while a disjunction has to name the arm that
/// killed it.
enum SettingGate: Hashable {
    case setting(SettingKey)
    case anyOf([SettingKey])
    case runtime(SettingRuntimeGate)
    /// The row is inert while ANY of these conditions holds —
    /// the runtime peer of `.anyOf`, so a row with a two-arm
    /// predicate names both arms instead of one tag standing for
    /// the pair.
    case runtimeAnyOf([SettingRuntimeGate])

    /// The setting rows this gate reads, for the guards.
    var settings: [SettingKey] {
        switch self {
        case .setting(let key): return [key]
        case .anyOf(let keys): return keys
        case .runtime, .runtimeAnyOf: return []
        }
    }

    /// The runtime conditions this gate names, for the guards.
    var runtimeConditions: [SettingRuntimeGate] {
        switch self {
        case .setting, .anyOf: return []
        case .runtime(let condition): return [condition]
        case .runtimeAnyOf(let conditions): return conditions
        }
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
