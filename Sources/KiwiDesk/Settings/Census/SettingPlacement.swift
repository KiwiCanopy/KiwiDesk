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

/// A titled card or group within an area.
enum SettingsContainer: CaseIterable, Hashable {
    case about
    case advanced
    case appBar
    case borders
    case bsp
    case dragAndDrop
    case focus
    case focusBorder
    case gaps
    case general
    case generalKeys
    case grid
    case language
    case layers
    case login
    case luaBindings
    case monitorFingerprints
    case monocle
    case motion
    case mouse
    case moveWindows
    case onQuit
    case openApplications
    case palettes
    case perSpaceOverrides
    case pinnedToDisconnectedMonitors
    case profilesPerMacOSSpace
    case rulesPerApp
    case savedProfiles
    case scrolling
    case sizeAndFloat
    case spaceBar
    case spaceList
    case spacePlacement
    case stack
    case stickyWindows
    case track

    /// The gate that greys this container's rows AS A UNIT,
    /// where the live editor greys wholesale (the App Bar and
    /// Space Bar editors off their bar-shown switches, Focus
    /// border off its enable toggle, the animations card under
    /// macOS Reduce Motion). Composes with each row's own
    /// `SettingPlacement.gate` (both apply); a row that OWNS
    /// the container gate stays live implicitly, and a row the
    /// live wiring deliberately leaves outside the block gate
    /// sets `exemptFromContainerGate`. Containers whose greys
    /// have no single owning switch (Drag & drop's two halves)
    /// record nothing here — the row gates carry the owners.
    var gate: SettingGate? {
        switch self {
        case .appBar:
            return .anyOf([
                .layoutAppBar(.monocleAppBarEnabled),
                .layoutAppBar(.scrollingAppBarEnabled),
            ])
        case .spaceBar:
            return .setting(.spaceBar(.spaceBarEnabled))
        case .focusBorder:
            return .setting(.borders(.borderEnabled))
        case .motion:
            return .runtime(.reduceMotion)
        case .about, .advanced, .borders, .bsp, .dragAndDrop,
            .focus, .gaps, .general, .generalKeys, .grid,
            .language, .layers, .login, .luaBindings,
            .monitorFingerprints, .monocle, .mouse,
            .moveWindows, .onQuit, .openApplications,
            .palettes, .perSpaceOverrides,
            .pinnedToDisconnectedMonitors,
            .profilesPerMacOSSpace, .rulesPerApp,
            .savedProfiles, .scrolling, .sizeAndFloat,
            .spaceList, .spacePlacement, .stack,
            .stickyWindows, .track:
            return nil
        }
    }
}

/// How deep a setting sits (decision-log item 12). "Show more"
/// rows and nerd-only cards are different things — never
/// conflate them in copy or code (item 7): `.showMore` is a
/// row-level disclosure; mode depth is
/// `SettingsArea.minimumMode`.
enum SettingTier: Hashable {
    /// Visible at rest in its container.
    case atRest
    /// Behind the container's "Show more" disclosure.
    case showMore
    /// Surfaces without disclosure the moment its gate allows.
    /// No census row uses it yet: the placement table encodes
    /// conditional surfacing as a `.runtime` gate on an
    /// atRest/showMore row, and this tier waits for the
    /// mode-mechanics phase, which item 12 names it for.
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
    /// Desktop bindings are global — dead while a stored
    /// profile is being edited (switch to Live).
    case editingStoredProfile
    /// Presets apply only when the connected screen count
    /// matches the preset's.
    case screenCountMismatch
    /// The login item follows `SMAppService` status — the
    /// setter is guarded, the picker greys (#342).
    case loginItemServiceStatus
    /// The per-space reset action is dead while the space has
    /// no overrides.
    case spaceHasNoOverrides
    /// macOS Reduce Motion greys the animations card.
    case reduceMotion
    /// The orphaned-pins card exists only while a space is
    /// pinned to a disconnected monitor.
    case orphanPinsExist
    /// The not-connected banner shows only while a pinned
    /// monitor is absent.
    case monitorsDisconnected
    /// The neon "Pair with Glow" link shows only for palettes
    /// that carry the glow pairing (#578).
    case paletteGlowPairing
    /// The import row shows only while `init.lua` holds
    /// bindings the GUI can adopt.
    case luaImportAvailable
}

/// What greys a surfaced row (the placement table's GATED
/// rows). `.setting` / `.anyOf` name the surfaced rows whose
/// values decide the grey — the exact predicate (resolved
/// override chains, value comparisons) lives with the wiring,
/// and gates on resolved values name every surfaced owner
/// (#406: gate on RESOLVED, not global). `.runtime` names a
/// condition that is not itself a setting.
enum SettingGate: Hashable {
    case setting(SettingKey)
    case anyOf([SettingKey])
    case runtime(SettingRuntimeGate)

    /// The setting rows this gate reads, for the guards.
    var settings: [SettingKey] {
        switch self {
        case .setting(let key): return [key]
        case .anyOf(let keys): return keys
        case .runtime: return []
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
