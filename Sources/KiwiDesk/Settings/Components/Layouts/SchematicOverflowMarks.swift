import AppKit
import KiwiDeskCore
import SwiftUI

/// A schematic run as the engine lays it: its `ZoneRun` and every
/// member's rect, the hidden ones behind their edge slot.
struct SchematicLaidRun {
    let run: ZoneRun
    let rects: [CGRect]
    let vertical: Bool

    /// The overflow marks the desk would draw on this run, asked of
    /// Core's own rule (`OverflowMark.ends`, #2864).
    var ends: [OverflowMark.RunEnd] {
        OverflowMark.ends(of: run, vertical: vertical)
    }
}

/// Draws a run's overflow marks where the desk draws them: the
/// "+n" on each end's edge window, placed by Core's
/// `OverflowMark.frame` within the run's `bounds` (#2864, #2235).
struct SchematicOverflowMarks: View {
    let laid: SchematicLaidRun
    let bounds: CGRect

    var body: some View {
        ForEach(laid.ends, id: \.end) { end in
            let count = end.hidden.count
            let rect = OverflowMark.frame(
                end: end.end,
                size: SchematicMoreChip.size(
                    hidden: count,
                    pill: end.end.isPill
                ),
                anchor: laid.rects[end.anchor],
                bounds: bounds
            )
            SchematicMoreChip(hidden: count, pill: end.end.isPill)
                .position(x: rect.midX, y: rect.midY)
                .zIndex(1)
        }
    }
}
