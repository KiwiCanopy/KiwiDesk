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
                    SchematicPileTile()
                        .frame(
                            width: slots[i].width,
                            height: slots[i].height
                        )
                        .position(x: slots[i].midX, y: slots[i].midY)
                }
            }
        }
    }

    /// The overflowed windows piling down the overflow track
    /// (always vertical), the same shape as the Stack cascade:
    /// `cascade_all` piles all of them; `cascade_overflow` tiles
    /// the ones that fit and piles the rest. Only reached with at
    /// least one window to draw.
    private func overflowSlots(_ size: CGSize) -> [CGRect] {
        let n = overflowWindows
        let w = size.width
        let h = size.height
        // Track keeps its own, narrower reveal rather than the
        // family's: its overflow track is one slice of the strip,
        // so the wider reveal trips the tile-height floor sooner
        // and the pile leaves its zone. The shared value is the
        // Stack/Grid one; this is a deliberate divergence, not a
        // missed rename.
        let off: CGFloat = 6
        if overflowStyle == .cascadeAll {
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
        let tiled = min(3, max(0, n - 1))
        let piled = n - tiled
        let g: CGFloat = 3
        let rowH = max(
            8,
            (h - g * CGFloat(tiled) - off * CGFloat(piled - 1))
                / CGFloat(tiled + 1)
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
