import KiwiDeskCore

/// Resolves Shortcuts census gates (#678 Phase 3, `LayersCard`,
/// `ShortcutsGateTests`).
struct ShortcutsGates {
    let config: GuiConfig

    /// Reason why a Shortcuts setting is withheld or gated.
    enum InertReason: Hashable {
        /// Only default layer configured (`.layersExist`).
        case onlyDefaultLayer
    }

    /// Evaluates inert reason for setting key.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .shortcuts(.layers), .shortcuts(.layersIcon),
            .shortcuts(.switchToLayer):
            return config.layers.count > 1 ? nil : .onlyDefaultLayer
        default:
            assertionFailure(
                "ShortcutsGates does not own \(key.id)"
            )
            return nil
        }
    }

    /// Gated keys resolved directly from `GuiConfig`
    /// (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .shortcuts(.layers),
        .shortcuts(.layersIcon),
        .shortcuts(.switchToLayer),
    ]

    /// Gated keys resolved dynamically in view state (`ShortcutsHeader`).
    static let resolvedElsewhere: Set<SettingKey> = [
        .shortcuts(.`import`),
        .shortcuts(.restoreDefaults),
    ]
}
