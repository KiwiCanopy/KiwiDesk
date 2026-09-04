import KiwiDeskCore

/// Resolves Shortcuts census gates (#678 Phase 3). This area's
/// one gate SURFACES rather than greys: non-nil means "not yet at
/// rest" (withheld behind the offer), so there is no inline
/// sentence and no `GateHelp` companion. `LayersCard` asks this
/// rather than re-deriving — a renderer whose predicate silently
/// disagreed once hid a user's own configured layers
/// (`ShortcutsGateTests`).
struct ShortcutsGates {
    let config: GuiConfig

    /// Reason why a Shortcuts setting is withheld or gated.
    enum InertReason: Hashable, CaseIterable {
        /// Only default layer configured (`.layersExist`).
        case onlyDefaultLayer
    }

    /// Evaluates inert reason for setting key.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .shortcuts(.layers), .shortcuts(.layersIcon),
            .shortcuts(.switchToLayer):
            // `default` always exists, so a SECOND entry is what
            // "the user configured a layer" means — presence, not
            // a count.
            return config.layers.count > 1 ? nil : .onlyDefaultLayer
        default:
            assertionFailure(
                "ShortcutsGates does not own \(key.id)"
            )
            return nil
        }
    }

    /// Whether the user has a layer to CHOOSE between — the one
    /// spelling of that question (#1127). Written against the
    /// case rather than against nil: a second `InertReason`
    /// arriving for some other cause would otherwise stop the
    /// preview caption and the header naming their layer, for a
    /// reason that has nothing to do with how many there are.
    var layersExist: Bool {
        inertReason(for: .shortcuts(.switchToLayer))
            != .onlyDefaultLayer
    }

    /// Gated keys resolved directly from `GuiConfig`
    /// (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .shortcuts(.layers),
        .shortcuts(.layersIcon),
        .shortcuts(.switchToLayer),
    ]

    /// Gated keys resolved dynamically in view state: Import's
    /// and Restore Defaults' gates are live-editor questions no
    /// saved `GuiConfig` can answer, so `ShortcutsHeader` keeps
    /// them. Naming them keeps the gap deliberate.
    static let resolvedElsewhere: Set<SettingKey> = [
        .shortcuts(.`import`),
        .shortcuts(.restoreDefaults),
    ]
}
