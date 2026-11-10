import KiwiDeskCore

extension SettingsModel {
    /// The reach the draft encodes a row at when nothing is picked —
    /// the encoder's own `RuleReachDraft.defaultReach`, one copy.
    func storedDefault(
        _ family: RuleFamily,
        _ app: String
    ) -> RuleReach? {
        guard let stored = layeredReach, let editing = reachProfile
        else { return nil }
        let key = family.key(app)
        switch family {
        case .space:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.appRules,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .float:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.floatRules,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .key:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.keyLayers,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .scroll:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.scrollGestures,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .history:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.spaceHistory,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .wrap:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.focusWrap,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .cycle:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.modeCycle,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .tile:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.tileRules,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .autoFloat:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.floatAutomatically,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .tilingStart:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.tilingStart,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .tilingOffHides:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.tilingOffHides,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        }
    }
}
