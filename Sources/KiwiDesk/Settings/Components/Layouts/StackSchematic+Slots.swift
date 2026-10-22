import KiwiDeskCore
import SwiftUI

/// Stack zone schematic slot geometry (#222, #2235).
extension StackSchematic {
    /// The stack zone's slots: the first `shownRows` windows share
    /// the zone, and every one after waits exactly behind the last
    /// shown slot, as `ZoneRun` places a run resting at its head.
    func stackSlots(in size: CGSize) -> [Slot] {
        let n = stackWins.count
        guard n > 0 else { return [] }
        let shown = min(Self.shownRows, n)
        let g: CGFloat = 3
        let vertical = stackOrientation == .vertical
        let along = vertical ? size.height : size.width
        let extent = max(
            vertical ? 10 : 6,
            (along - g * CGFloat(shown - 1)) / CGFloat(shown)
        )
        return (0..<n).map { index in
            let position = CGFloat(min(index, shown - 1)) * (extent + g)
            return Slot(
                rect: vertical
                    ? CGRect(
                        x: 0,
                        y: position,
                        width: size.width,
                        height: extent
                    )
                    : CGRect(
                        x: position,
                        y: 0,
                        width: extent,
                        height: size.height
                    ),
                hidden: index >= shown
            )
        }
    }
}
