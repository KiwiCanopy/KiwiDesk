import KiwiDeskCore

/// Resolves the KiwiVision rows' declared runtime gates (#2103,
/// `BarsGates`' shape): every row is app-wide (#1741), so it greys
/// only where `init.lua` owns the config. The card's Reduce
/// transparency gate is read from the environment at the card.
struct KiwiVisionGates {
    var guiManaged: Bool

    enum InertReason: Hashable {
        /// `init.lua` owns the config, so an app-wide row it does
        /// not store is not the GUI's to write (#1741).
        case appWideLuaOwned
    }

    /// Runtime-gated keys this resolver answers directly.
    static let resolved: Set<SettingKey> = [
        .kiwiVision(.dim), .kiwiVision(.blur),
        .kiwiVision(.appearance), .kiwiVision(.clearWallpaper),
        .kiwiVision(.clearApp), .kiwiVision(.neverDimmed),
        .kiwiVision(.lenses),
    ]

    func inertReason(for key: SettingKey) -> InertReason? {
        switch key {
        case .kiwiVision:
            return guiManaged ? nil : .appWideLuaOwned
        default:
            assertionFailure("KiwiVisionGates does not own \(key.id)")
            return nil
        }
    }

    @MainActor static func sentence(for reason: InertReason) -> String {
        switch reason {
        case .appWideLuaOwned:
            return GeneralGateHelp.sentence(for: .luaOwned)
        }
    }
}
