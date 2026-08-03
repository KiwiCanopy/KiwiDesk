import KiwiDeskCore
import SwiftUI

/// The stack zone's slot math, split from `StackSchematic` when
/// the #222 arrangement branches grew it past the line ceiling
/// (AGENTS.md §2). Pure geometry over the mini canvas; the view
/// side stays in `StackSchematic.swift`.
extension StackSchematic {
    /// `cascade_all` piles every window (always downward, like
    /// the engine's `OverlapStack`); `cascade_overflow` tiles
    /// the run along the staged stack orientation and piles the
    /// surplus at the zone's trailing end. Piled tiles keep
    /// their extent but overlap by `cascadeOffset`, so only
    /// their top edge shows above the next.
    func stackSlots(in size: CGSize) -> [Slot] {
        let n = stackWins.count
        // Driven by the preview's window count since turn 10, so
        // the divisions below are live arithmetic rather than a
        // formality: an empty stack zone (every window a master)
        // draws nothing at all.
        guard n > 0 else { return [] }
        let w = size.width
        let h = size.height
        let off = Self.cascadeOffset
        if overflowStyle == .cascadeAll {
            // The whole zone piles downward regardless of the
            // zone's orientation, exactly like the engine.
            let tileH = max(10, h - off * CGFloat(n - 1))
            return (0..<n).map { i in
                Slot(
                    rect: CGRect(
                        x: 0,
                        y: CGFloat(i) * off,
                        width: w,
                        height: tileH
                    ),
                    piled: true,
                    front: i == n - 1
                )
            }
        }
        let tiled = min(Self.overflowTiled, n - 1)
        let piled = n - tiled
        let g: CGFloat = 3
        if stackOrientation == .horizontal {
            // Tiles side by side; the surplus piles downward in
            // the last column (`OverlapStack.overflowFrames`
            // with a horizontal tiling axis).
            let colW = max(
                6,
                (w - g * CGFloat(tiled)) / CGFloat(tiled + 1)
            )
            var slots: [Slot] = []
            for i in 0..<tiled {
                slots.append(
                    Slot(
                        rect: CGRect(
                            x: CGFloat(i) * (colW + g),
                            y: 0,
                            width: colW,
                            height: h
                        ),
                        piled: false,
                        front: false
                    )
                )
            }
            let left = CGFloat(tiled) * (colW + g)
            let pileH = max(10, h - off * CGFloat(piled - 1))
            for k in 0..<piled {
                slots.append(
                    Slot(
                        rect: CGRect(
                            x: left,
                            y: CGFloat(k) * off,
                            width: colW,
                            height: pileH
                        ),
                        piled: true,
                        front: k == piled - 1
                    )
                )
            }
            return slots
        }
        let rowH = max(
            10,
            (h - g * CGFloat(tiled) - off * CGFloat(piled - 1))
                / CGFloat(tiled + 1)
        )
        var slots: [Slot] = []
        for i in 0..<tiled {
            slots.append(
                Slot(
                    rect: CGRect(
                        x: 0,
                        y: CGFloat(i) * (rowH + g),
                        width: w,
                        height: rowH
                    ),
                    piled: false,
                    front: false
                )
            )
        }
        let top = CGFloat(tiled) * (rowH + g)
        for k in 0..<piled {
            slots.append(
                Slot(
                    rect: CGRect(
                        x: 0,
                        y: top + CGFloat(k) * off,
                        width: w,
                        height: rowH
                    ),
                    piled: true,
                    front: k == piled - 1
                )
            )
        }
        return slots
    }
}
