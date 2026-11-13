import Foundation

/// A screen holding one Space (#3294): it takes the first layout
/// of its shape's single-Space order that no other screen on the
/// desk holds, so a four-screen desk keeps its variety.
extension StarterAllocation {
    /// A one-Space screen's candidates, best first (#3294): the
    /// shape's `ScreenClass.layouts`, the laptop's reversed to lead
    /// Monocle — one Space on a small screen is a screen of whole
    /// windows.
    static func singleSpaceOrder(for shape: ScreenClass)
        -> [LayoutMode]
    {
        shape == .laptop ? shape.layouts.reversed() : shape.layouts
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
    /// the screens of two or more Spaces are placed. Beside an
    /// ultrawide a non-ultrawide never scrolls: its Scrolling pick
    /// becomes Monocle (#1662, #3294).
    static func fillSingleSpaces(
        _ result: inout [[LayoutMode]],
        shares: [Int],
        shapes: [ScreenClass],
        order: [Int],
        besideUltrawide: Bool
    ) {
        for index in order where shares[index] == 1 {
            let shape = shapes[index]
            let pick = singleSpaceLayout(
                for: shape,
                placed: result.flatMap { $0 }
            )
            let scrollsHere = !besideUltrawide || shape.isUltrawide
            result[index] = [
                pick == .scrolling && !scrollsHere ? .monocle : pick
            ]
        }
    }
}
