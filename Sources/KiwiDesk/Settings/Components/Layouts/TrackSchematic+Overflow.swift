import KiwiDeskCore
import SwiftUI

/// Overflow track layout and slot geometry for TrackSchematic.
extension TrackSchematic {
    /// Renders cascade or overflow pile in far-edge track.
    var overflowTrack: some View {
        GeometryReader { geo in
            let slots = overflowSlots(geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(slots.indices, id: \.self) { i in
                    // A `last` own-track past the cap IS the
                    // overflow's newest member (#1354): the `+`
                    // rides the top of the pile, where the engine
                    // puts it, rather than a column the limit
                    // does not allow.
                    SchematicPileTile(
                        isNew: incomingFolds && i == slots.count - 1
                    )
                    .frame(
                        width: slots[i].width,
                        height: slots[i].height
                    )
                    .position(x: slots[i].midX, y: slots[i].midY)
                }
            }
        }
    }

    /// The overflow track's windows (always vertical), the same
    /// shape as the Stack cascade and on the same contract
    /// (`set_overflow_style`): a cascade begins only WHEN the
    /// track overflows — more windows than fit, the stand-in
    /// `trackSpillCapacity` standing for "fit at the minimum
    /// size" as it does for the fill rule — and then
    /// `cascade_all` piles all of them while `cascade_overflow`
    /// keeps the fitting ones tiled and piles the rest. Below the
    /// fit both styles tile, as the layout does (#1354). Only
    /// reached with at least one window to draw.
    func overflowSlots(_ size: CGSize) -> [CGRect] {
        let n = overflowWindows
        let w = size.width
        let h = size.height
        let fits = LayoutSchematic.trackSpillCapacity
        // Track keeps its own, narrower reveal rather than the
        // family's: its overflow track is one slice of the strip,
        // so the wider reveal trips the tile-height floor sooner
        // and the pile leaves its zone. The shared value is the
        // Stack/Grid one; this is a deliberate divergence, not a
        // missed rename.
        let off: CGFloat = 6
        if n > fits, overflowStyle == .cascadeAll {
            let tileH = max(6, h - off * CGFloat(n - 1))
            return (0..<n).map {
                CGRect(
                    x: 0,
                    y: CGFloat($0) * off,
                    width: w,
                    height: tileH
                )
            }
        }
        let tiled = min(fits, n)
        let piled = n - tiled
        let g: CGFloat = 3
        // Tiled rows share the height with the pile's top row;
        // with nothing piled, the rows alone divide it.
        let rows = CGFloat(tiled + (piled > 0 ? 1 : 0))
        let rowH = max(
            8,
            (h - g * CGFloat(max(0, Int(rows) - 1))
                - off * CGFloat(max(0, piled - 1))) / rows
        )
        var rects: [CGRect] = []
        for i in 0..<tiled {
            rects.append(
                CGRect(
                    x: 0,
                    y: CGFloat(i) * (rowH + g),
                    width: w,
                    height: rowH
                )
            )
        }
        let top = CGFloat(tiled) * (rowH + g)
        for k in 0..<piled {
            rects.append(
                CGRect(
                    x: 0,
                    y: top + CGFloat(k) * off,
                    width: w,
                    height: rowH
                )
            )
        }
        return rects
    }

}
