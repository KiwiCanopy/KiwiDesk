import CoreGraphics
import Foundation

/// The allocation when an ultrawide sits among several screens
/// (#1662): Scrolling lives on the ultrawides alone, every other
/// screen leads Monocle, and each screen gets its ruled layout and
/// its own Floating space — per screen, whatever the others drew.
/// It owns its own lead; the ladder's is `lead(_:of:)`.
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
    /// `hasUltrawideCompanion`: lead, ruled layout, Floating, as far
    /// as the screen's share reaches.
    static func ultrawideModes(sizes: [CGSize]) -> [[LayoutMode]] {
        let widths = sizes.map(\.width)
        let shapes = sizes.map(ScreenClass.of)
        let share = shares(
            widths: widths,
            budget: ultrawideBudget(screenCount: sizes.count)
        )
        var ultrawideTiled: Set<LayoutMode> = []
        var result = [[LayoutMode]](repeating: [], count: sizes.count)
        for index in fillOrder(widths: widths) {
            let shape = shapes[index]
            var modes: [LayoutMode] = [
                shape.isUltrawide ? .scrolling : .monocle
            ]
            if share[index] >= 3 {
                modes.append(
                    ruledLayout(for: shape, beside: &ultrawideTiled)
                )
            }
            if share[index] >= 2 { modes.append(.floating) }
            result[index] = modes
        }
        return result
    }

    /// A screen's one tiled layout here (owner ruling, #1662): a
    /// widescreen BSP, a portrait or laptop screen Grid. An
    /// ultrawide takes Stack, a second ultrawide Track, so two
    /// ultrawides never share one Stack's tuning.
    static func ruledLayout(
        for shape: ScreenClass,
        beside ultrawideTiled: inout Set<LayoutMode>
    ) -> LayoutMode {
        switch shape {
        case .desktop:
            return .bsp
        case .pivoted, .laptop:
            return .grid
        case .superUltrawide, .ultrawide:
            let mode: LayoutMode =
                ultrawideTiled.contains(.stack) ? .track : .stack
            ultrawideTiled.insert(mode)
            return mode
        }
    }
}
