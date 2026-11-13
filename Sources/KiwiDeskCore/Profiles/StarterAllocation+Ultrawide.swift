import CoreGraphics
import Foundation

/// The allocation when an ultrawide sits among several screens
/// (#1662): Scrolling leads the ultrawides alone, every other
/// screen of two or more Spaces leads Monocle, and each such
/// screen gets its ruled layout and its own Floating space. The
/// budget is the ladder's (#3294); from `wideDeskScreens` only the
/// widest ULTRAWIDE holds two, so one Floating overrides the
/// per-screen ones. A one-Space screen takes
/// `singleSpaceLayout(for:placed:)`, Monocle for Scrolling off the
/// ultrawides. It owns its own lead; the ladder's is `lead(_:of:)`.
extension StarterAllocation {
    /// Whether these screens take the ultrawide allocation.
    static func hasUltrawideCompanion(_ sizes: [CGSize]) -> Bool {
        sizes.count > 1
            && sizes.contains { ScreenClass.of($0).isUltrawide }
    }

    /// Layouts per screen in positional order, for a setup that
    /// `hasUltrawideCompanion`: lead, ruled layout, Floating, as far
    /// as the screen's share reaches.
    static func ultrawideModes(sizes: [CGSize]) -> [[LayoutMode]] {
        let widths = sizes.map(\.width)
        let shapes = sizes.map(ScreenClass.of)
        let order = fillOrder(widths: widths)
        let share = deskShares(
            widths: widths,
            budget: budget(screenCount: sizes.count),
            widest: order.first { shapes[$0].isUltrawide }
        )
        var result = [[LayoutMode]](repeating: [], count: sizes.count)
        for index in order where share[index] > 1 {
            let shape = shapes[index]
            var modes: [LayoutMode] = [
                shape.isUltrawide ? .scrolling : .monocle
            ]
            if share[index] >= 3 {
                modes.append(ruledLayout(for: shape))
            }
            modes.append(.floating)
            result[index] = modes
        }
        fillSingleSpaces(
            &result,
            shares: share,
            shapes: shapes,
            order: order,
            besideUltrawide: true
        )
        return result
    }

    /// A screen's one tiled layout here (owner ruling, #1662): a
    /// widescreen BSP, a portrait or laptop screen Grid, an
    /// ultrawide Stack. The ladder's budget gives at most one
    /// screen three Spaces (#3294, `oneScreenAtMostHoldsThree`).
    static func ruledLayout(for shape: ScreenClass) -> LayoutMode {
        switch shape {
        case .desktop: .bsp
        case .pivoted, .laptop: .grid
        case .superUltrawide, .ultrawide: .stack
        }
    }
}
