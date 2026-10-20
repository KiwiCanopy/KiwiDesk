import Foundation

/// The session shadow a `revert_settings` write drops (#2411): the
/// session layer outranks every sizing leaf, so a reverted one
/// clears its field where it moved — globally for the layout's own
/// value, per Space for an override — as each setter does (#764).
extension KiwiCore {
    /// One `SessionRatios` field and the settings leaves it shadows.
    struct SizingShadow {
        let movedGlobally: (TilingSettings, TilingSettings) -> Bool
        let movedIn: (TilingSettings, TilingSettings) -> [SpaceID]
        let clear: (inout SessionRatios) -> Void

        init<G: Equatable, O, L: Equatable>(
            _ global: KeyPath<TilingSettings, G>,
            _ overrides: KeyPath<TilingSettings, [SpaceID: O]>,
            _ local: KeyPath<O, L>,
            clear: @escaping (inout SessionRatios) -> Void
        ) {
            movedGlobally = {
                $0[keyPath: global] != $1[keyPath: global]
            }
            movedIn = { old, new in
                let a = old[keyPath: overrides]
                let b = new[keyPath: overrides]
                return Set(a.keys).union(b.keys).filter {
                    a[$0]?[keyPath: local] != b[$0]?[keyPath: local]
                }
            }
            self.clear = clear
        }
    }

    /// One entry per `SessionRatios` field
    /// (`RevertSettingsApplyTests` ▸ `everyFieldHasAnEntry`).
    static var sizingShadows: [SizingShadow] {
        [
            SizingShadow(
                \.bsp.splitRatioH,
                \.bsp.override,
                \.splitRatioH
            ) { $0.splitRatioH = nil },
            SizingShadow(
                \.bsp.splitRatioV,
                \.bsp.override,
                \.splitRatioV
            ) { $0.splitRatioV = nil },
            SizingShadow(
                \.stack.masterRatio,
                \.stack.override,
                \.masterRatio
            ) { $0.masterRatio = nil },
            SizingShadow(
                \.scrolling.slotSize,
                \.scrolling.override,
                \.slotSize
            ) { $0.slotSize = nil },
            SizingShadow(
                \.grid.columnWeights,
                \.grid.override,
                \.columnWeights
            ) { $0.gridColumnWeights = nil },
            SizingShadow(
                \.grid.rowWeights,
                \.grid.override,
                \.rowWeights
            ) { $0.gridRowWeights = nil },
        ]
    }

    /// Drops the session shadow of every sizing leaf `new` moved
    /// from `old`.
    func clearSessionShadows(
        from old: TilingSettings,
        to new: TilingSettings
    ) {
        for shadow in Self.sizingShadows {
            if shadow.movedGlobally(old, new) {
                clearSessionRatios(shadow.clear)
            }
            for space in shadow.movedIn(old, new) {
                clearSessionRatios(for: space, shadow.clear)
            }
        }
    }
}
