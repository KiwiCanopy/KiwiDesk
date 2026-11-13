import Foundation

/// A screen holding one Space (#3294): it takes the first layout
/// of its shape's single-Space order that no other screen on the
/// desk holds, so a four-screen desk keeps its variety.
extension StarterAllocation {
    /// A one-Space screen's candidates, best first (#3294). The
    /// laptop's leads Monocle, the opposite of its
    /// `ScreenClass.layouts`: one Space on a small screen is a
    /// screen of whole windows.
    static func singleSpaceOrder(for shape: ScreenClass)
        -> [LayoutMode]
    {
        switch shape {
        case .laptop:
            [.monocle, .scrolling]
        case .desktop:
            [.grid, .stack, .bsp, .scrolling]
        case .superUltrawide, .ultrawide:
            [.stack, .track, .grid]
        case .pivoted:
            [.stack, .grid, .monocle]
        }
    }

    /// The layout a one-Space screen of `shape` takes beside the
    /// layouts already `placed` on the desk: the first of its
    /// order placed nowhere, else the one placed least, earlier
    /// in the order winning a tie.
    static func singleSpaceLayout(
        for shape: ScreenClass,
        placed: [LayoutMode]
    ) -> LayoutMode {
        let order = singleSpaceOrder(for: shape)
        let uses = order.map { mode in
            placed.count(where: { $0 == mode })
        }
        let best = uses.indices.min { uses[$0] < uses[$1] } ?? 0
        return order[best]
    }

    /// Fills every screen whose share is one, widest first, after
    /// the screens of two or more Spaces are placed.
    static func fillSingleSpaces(
        _ result: inout [[LayoutMode]],
        shares: [Int],
        shapes: [ScreenClass],
        order: [Int]
    ) {
        for index in order where shares[index] == 1 {
            result[index] = [
                singleSpaceLayout(
                    for: shapes[index],
                    placed: result.flatMap { $0 }
                )
            ]
        }
    }
}
