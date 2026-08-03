import KiwiDeskCore

/// Resolves the census's `.runtime` gates for the Shortcuts area
/// (#678 Phase 3).
///
/// A census `gate:` used to be a *label* — it named the condition
/// and the renderer re-implemented it inline, which is the #520
/// drift the Bars lane already met for greying. Here the stakes
/// are higher: `.layersExist` gates a `.immediate` TIER, and a
/// tier decides whether a control is on screen at all. A renderer
/// whose predicate silently disagreed with the census would hide
/// a user's own configured layers, which is the exact defect this
/// area shipped once.
///
/// So the census gate is the authority and `LayersCard` calls
/// this rather than re-deriving. Pure over `GuiConfig` on
/// purpose: that is what makes it assertable without a view, and
/// `ShortcutsRuntimeGateTests` pins each case against a config
/// that satisfies it and one that does not.
///
/// **Only the gates resolvable from the config live here.** The
/// area's other runtime gate, `.luaImportAvailable`, is a
/// conjunction over live editor state (`hasCustomLua` AND not
/// editing a stored profile) that no `GuiConfig` can answer;
/// `ShortcutsHeader` keeps it, and `unresolvableGatesAreDeclared`
/// pins that the split is deliberate rather than an omission.
enum ShortcutsRuntimeGate {
    /// Whether `gate` currently allows its row to surface.
    ///
    /// Fail-OPEN on a gate this type does not own — loud in
    /// debug, surfacing in release — matching `BarsGates` and the
    /// renderers' unhandled-census-key arms, which is the one
    /// policy this codebase has for this failure class. A missing
    /// case must not crash a shipped Settings window, and of the
    /// two silent readings, surfacing a row the user can ignore
    /// beats hiding one they cannot find.
    ///
    /// `everyRuntimeGateIsAccountedFor` keeps this arm
    /// unreachable rather than merely believed to be.
    static func isSatisfied(
        _ gate: SettingRuntimeGate,
        in config: GuiConfig
    ) -> Bool {
        switch gate {
        case .layersExist:
            // `default` always exists, so a SECOND entry is what
            // "the user configured a layer" means — and that is
            // the whole condition, because config presence is
            // the rule: an existing layer surfaces its card in
            // both Settings modes, and only the offer to create
            // the first one is withheld.
            return config.layers.count > 1
        default:
            assertionFailure(
                "ShortcutsRuntimeGate does not own \(gate)"
            )
            return true
        }
    }

    /// The Shortcuts-area runtime gates this type resolves.
    /// Data, so the guard can assert the split against the census
    /// instead of restating it.
    static let resolved: Set<SettingRuntimeGate> = [.layersExist]

    /// Runtime gates the area declares but resolves elsewhere,
    /// each because the condition is not a function of the saved
    /// config. Naming them is what keeps the gap deliberate: a
    /// new runtime gate lands in neither set and reds the guard.
    static let resolvedElsewhere: Set<SettingRuntimeGate> = [
        .luaImportAvailable
    ]
}
