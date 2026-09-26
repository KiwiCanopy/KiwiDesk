import CoreGraphics
import Foundation

/// The allocation when an ultrawide sits among several screens
/// (#1662): Scrolling lives on the ultrawides alone, every other
/// screen leads Monocle, and each screen ends in its own Floating
/// space.
extension StarterAllocation {
    /// Whether these screens take the ultrawide allocation.
    static func hasUltrawideCompanion(_ sizes: [CGSize]) -> Bool {
        sizes.count > 1
            && sizes.contains { ScreenClass.of($0).isUltrawide }
    }

    /// Three spaces a screen, capped at `softCap` — the one place
    /// the ladder does not apply (owner ruling, #1662).
    static func ultrawideBudget(screenCount: Int) -> Int {
        max(screenCount, min(softCap, maxShare * screenCount))
    }

    /// Layouts per screen in positional order, for a setup that
    /// `hasUltrawideCompanion`.
    static func ultrawideModes(sizes: [CGSize]) -> [[LayoutMode]] {
        let widths = sizes.map(\.width)
        let shapes = sizes.map(ScreenClass.of)
        let share = shares(
            widths: widths,
            budget: ultrawideBudget(screenCount: sizes.count)
        )
        var used: Set<LayoutMode> = []
        var result = [[LayoutMode]](repeating: [], count: sizes.count)
        for index in fillOrder(widths: widths) {
            let lead: LayoutMode =
                shapes[index].isUltrawide ? .scrolling : .monocle
            var modes = [lead]
            used.insert(lead)
            let floats = share[index] >= 2
            let quota = share[index] - 1 - (floats ? 1 : 0)
            modes += take(
                quota,
                from: companionLayouts(for: shapes[index]),
                used: &used,
                beside: modes
            )
            if floats { modes.append(.floating) }
            result[index] = modes
        }
        return result
    }

    /// A screen's tiled layouts beside an ultrawide, never
    /// Scrolling or its Monocle lead (owner ruling, #1662): a
    /// widescreen takes Stack then BSP, a laptop a two-wide Grid.
    static func companionLayouts(
        for shape: ScreenClass
    ) -> [LayoutMode] {
        let list: [LayoutMode] =
            switch shape {
            case .desktop: [.stack, .bsp]
            case .laptop: [.grid]
            default: shape.layouts
            }
        return list.filter { $0 != .scrolling && $0 != .monocle }
    }
}
