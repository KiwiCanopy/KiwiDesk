/// Derives which channel conveys a gated row's disabled reason (#527, #815,
/// GreyOutAnchorTests, GateReasonPlacementTests).
enum GateReasonPlacement {
    /// Delivery channel for a gated row's explanation.
    enum Channel: Hashable {
        /// Gating control or condition is visible in the same container.
        case adjacent
        /// Gating control lives on another destination.
        case remote
        /// Gating condition requires an inline explanation (#815).
        case inline
    }

    /// Whether this row's gate needs its reason drawn inline.
    static func owesInlineReason(
        _ key: SettingKey,
        placement: (SettingKey) -> SettingPlacement = {
            $0.placement
        }
    ) -> Bool {
        channel(key, placement: placement) == .inline
    }

    /// Channel for the row's reason, or nil if ungated.
    static func channel(
        _ key: SettingKey,
        placement: (SettingKey) -> SettingPlacement = {
            $0.placement
        }
    ) -> Channel? {
        let row = placement(key)
        guard let gate = row.gate, let area = row.area else {
            return nil
        }
        switch gate {
        case .setting, .anyOf:
            let owners = gate.settings.map(placement)
            if owners.contains(where: {
                $0.area == area && $0.container == row.container
                    && $0.tier.visibilityRank
                        <= row.tier.visibilityRank
            }) {
                return .adjacent
            }
            if owners.allSatisfy({ $0.area != area }) {
                return .remote
            }
            return .inline
        case .runtime(let condition):
            guard condition.greys else { return nil }
            return condition.causeIsOnSurface ? .adjacent : .inline
        case .runtimeAnyOf(let conditions):
            guard conditions.contains(where: \.greys) else {
                return nil
            }
            return conditions.filter(\.greys)
                .allSatisfy(\.causeIsOnSurface)
                ? .adjacent : .inline
        }
    }
}

extension SettingTier {
    /// Relative distance to see a row at this tier (lower is nearer).
    var visibilityRank: Int {
        switch self {
        case .atRest: return 0
        case .immediate, .showMore: return 1
        case .luaOnly, .internalOnly, .outsideSettings:
            return .max
        }
    }
}

extension SettingRuntimeGate {
    /// Whether this condition greys a row or gates drawing entirely.
    var greys: Bool {
        switch self {
        case .perEdgeValuesDiffer, .editingStoredProfile,
            .screenCountMismatch,
            .loginItemServiceStatus, .autoStartServiceLoaded,
            .spaceHasNoOverrides, .reduceMotion:
            return true
        case .orphanPinsExist, .monitorsDisconnected,
            .paletteGlowPairing, .luaImportAvailable,
            .layersExist, .liquidGlassUnavailable,
            .desktopBridgeAbsent, .desktopBindingsExist,
            .defaultsToRestore:
            return false
        }
    }

    /// Whether the gating condition is visible on the current surface
    /// (GateReasonPlacementTests).
    var causeIsOnSurface: Bool {
        switch self {
        case .perEdgeValuesDiffer:
            return true
        case .spaceHasNoOverrides:
            return true
        case .reduceMotion, .loginItemServiceStatus,
            .autoStartServiceLoaded:
            return false
        case .editingStoredProfile, .screenCountMismatch:
            return true
        case .orphanPinsExist, .monitorsDisconnected,
            .paletteGlowPairing, .luaImportAvailable,
            .layersExist, .liquidGlassUnavailable,
            .desktopBridgeAbsent, .desktopBindingsExist,
            .defaultsToRestore:
            return true
        }
    }
}
