import KiwiDeskCore

/// Resolves App Rules census gates (#1022, the `ShortcutsGates`
/// shape). The section and the row ask this rather than
/// re-deriving either condition beside a control, so the census
/// declaration and the drawing answer from one reading
/// (`AppRulesGateTests`).
struct AppRulesGates {
    let config: GuiConfig

    /// Reason a gated App Rules row is withheld or greyed.
    enum InertReason: Hashable, CaseIterable {
        /// The profile declares no Space (`.spaces(.spaceList)`).
        case noSpaces
        /// No float rule matches by title
        /// (`.titlePatternsExist`).
        case noTitlePatterns
    }

    /// Evaluates the inert reason for a gated App Rules key.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .appRules(.appRules):
            return config.spaces.isEmpty ? .noSpaces : nil
        case .appRules(.floatRulesPattern):
            return config.floatRules.contains(where: FloatFacet.isTitled)
                ? nil : .noTitlePatterns
        default:
            assertionFailure(
                "AppRulesGates does not own \(key.id)"
            )
            return nil
        }
    }

    /// Whether the profile declares a Space to open an app in.
    var hasSpaces: Bool {
        inertReason(for: .appRules(.appRules)) != .noSpaces
    }

    /// Whether any float rule the reader can see matches by
    /// title.
    var titlePatternsExist: Bool {
        inertReason(for: .appRules(.floatRulesPattern))
            != .noTitlePatterns
    }

    /// Gated keys this resolver answers
    /// (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .appRules(.appRules),
        .appRules(.floatRulesPattern),
    ]

    /// Gated keys answered outside this resolver — none; named so
    /// the gap stays deliberate, as in every sibling resolver.
    static let resolvedElsewhere: Set<SettingKey> = []
}
