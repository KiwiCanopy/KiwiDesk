import KiwiDeskCore

/// Resolves the Shortcuts area's census gates (#678 Phase 3),
/// folded onto the reason-case shape the rest of the redesigned
/// areas share (`GapsBordersGates`, `GeneralGates`,
/// `LayoutDefaultsGates`, 2026-08-03 convergence): a struct keyed
/// on a row's own `SettingKey`, returning a REASON case rather than
/// a Bool, with the answered / answered-elsewhere split held as
/// data.
///
/// This area's one resolvable gate is a SURFACING gate, not a
/// greying one: `.layersExist` decides whether the Layers card's
/// `.immediate` rows are at rest or withheld behind the offer to
/// create the first layer. So a non-nil reason here means "not yet
/// at rest" rather than "greyed", and there is no inline sentence
/// to render — `.onlyDefaultLayer` is a state the renderer reads,
/// not a why-you-cannot the user sees. That is the one way this
/// resolver differs from its siblings, and why it carries no
/// `GateHelp` companion where they do.
///
/// A census `gate:` used to be a *label* — it named the condition
/// and the renderer re-implemented it inline. Here the stakes are
/// high: `.layersExist` gates a `.immediate` TIER, and a tier
/// decides whether a control is on screen at all. A renderer whose
/// predicate silently disagreed would hide a user's own configured
/// layers, which is the exact defect this area shipped once. So
/// `LayersCard` asks this rather than re-deriving. Pure over
/// `GuiConfig` on purpose: that is what keeps it assertable without
/// a view, and `ShortcutsGateTests` pins the predicate on each side
/// of the boundary.
struct ShortcutsGates {
    let config: GuiConfig

    /// Why a Shortcuts row is not at rest. One case; a non-nil
    /// value WITHHOLDS the row behind its offer disclosure rather
    /// than greying it.
    enum InertReason: Hashable {
        /// Only `default` is configured, so the Layers rows are
        /// purely the offer to create the first layer — reachable
        /// behind a disclosure, not at rest.
        case onlyDefaultLayer
    }

    /// Why `key`'s row is withheld right now, or nil once it is at
    /// rest.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .shortcuts(.layers), .shortcuts(.layersIcon),
            .shortcuts(.switchToLayer):
            // `default` always exists, so a SECOND entry is what
            // "the user configured a layer" means — presence, not
            // a count, so three layers still reads "exists" and an
            // off-by-one would pass the boundary pair.
            return config.layers.count > 1 ? nil : .onlyDefaultLayer
        default:
            // Fail-OPEN — surfacing the row in release, loud in
            // debug — matching the reason-case family and the
            // renderers' unhandled-census-key arms: a gate this
            // resolver cannot answer would otherwise withhold a
            // row silently forever. `everyGatedRowIsResolved`
            // keeps this arm unreachable rather than merely
            // believed to be.
            assertionFailure(
                "ShortcutsGates does not own \(key.id)"
            )
            return nil
        }
    }

    /// The gated rows this resolver answers from the config. Data,
    /// so `everyGatedRowIsResolved` reds when a new gate lands in
    /// neither set. All three Layers rows carry the one
    /// `.layersExist` gate.
    static let resolved: Set<SettingKey> = [
        .shortcuts(.layers),
        .shortcuts(.layersIcon),
        .shortcuts(.switchToLayer),
    ]

    /// Gated rows the area declares but resolves elsewhere:
    /// Import's `.luaImportAvailable` is a live-editor-state
    /// conjunction (`init.lua` holds adoptable bindings AND a live
    /// profile is being edited) that no saved `GuiConfig` can
    /// answer, so `ShortcutsHeader` keeps it. Naming it is what
    /// keeps the gap deliberate rather than an omission.
    static let resolvedElsewhere: Set<SettingKey> = [
        .shortcuts(.`import`)
    ]
}
