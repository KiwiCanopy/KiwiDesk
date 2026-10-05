import Foundation

/// The Liquid Glass switch's stored leaves (#1307, #1517, #1620,
/// #1621, #1956): the one list the Settings master writes and reads, and
/// the one a look's glass writes (#1684), so no path can turn the
/// shelf's glass off and leave the other surfaces on.
extension TilingSettings {
    public static var liquidGlassLeaves: [WritableKeyPath<Self, Bool>] {
        [
            \.kiwishelf.liquidGlass,
            \.shortcutPanelLiquidGlass,
            \.dragLiquidGlass,
            \.stickyStyle.liquidGlass,
            \.spaceSwitchLiquidGlass,
        ]
    }

    /// Writes every glass leaf at once.
    public mutating func setLiquidGlass(_ on: Bool) {
        for leaf in Self.liquidGlassLeaves { self[keyPath: leaf] = on }
    }
}
