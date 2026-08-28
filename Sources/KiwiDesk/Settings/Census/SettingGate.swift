/// The census's gate vocabulary (#678, spec 4f), split out of
/// `SettingPlacement.swift` when that file crossed the size
/// ceiling: what a row can be inert BEHIND, in the two flavours
/// a census gate comes in — another setting's value, and a
/// runtime condition that is not a setting at all.

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
