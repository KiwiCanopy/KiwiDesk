import KiwiDeskCore
import SwiftUI

/// Stack zone schematic slot geometry (#222, #2235).
extension StackSchematic {
    /// The stack zone's slots, placed by the engine's own run
    /// (`ZoneRun`, gui.md #702): `shownRows` windows fit, the run
    /// shows the incoming window — the focus it takes — or else
    /// rests at the zone's head, and every other window waits
    /// exactly behind the edge slot.
    func stackSlots(in size: CGSize) -> [Slot] {
        guard let laid = stackRun(in: size) else { return [] }
        return laid.rects.enumerated().map { index, rect in
            Slot(rect: rect, hidden: !laid.run.visible.contains(index))
        }
    }

    /// The stack zone's run and every member's rect in it; nil for
    /// an empty zone.
    func stackRun(in size: CGSize) -> SchematicLaidRun? {
        let n = stackWins.count
        guard n > 0 else { return nil }
        let g: CGFloat = 3
        let vertical = stackOrientation == .vertical
        let along = vertical ? size.height : size.width
        let shown = min(Self.shownRows, n)
        let extent = max(
            vertical ? 10 : 6,
            (along - g * CGFloat(shown - 1)) / CGFloat(shown)
        )
        // Floors that let exactly `shownRows` windows fit, a hair
        // under the slot so rounding never drops the last one.
        let floors = Array(repeating: extent - 0.01, count: n)
        let run = ZoneRun.resolve(
            floors: floors,
            span: along,
            gap: g,
            head: nil,
            focus: stackWins.firstIndex(of: newWindow)
        )
        let rects = run.frames(
            floors: floors,
            weights: Array(repeating: 1, count: n),
            in: CGRect(origin: .zero, size: size),
            vertical: vertical,
            gap: g
        )
        return SchematicLaidRun(run: run, rects: rects, vertical: vertical)
    }
}
