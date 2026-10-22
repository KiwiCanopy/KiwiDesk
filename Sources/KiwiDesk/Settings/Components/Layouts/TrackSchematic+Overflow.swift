import KiwiDeskCore
import SwiftUI

/// Overflow track layout and slot geometry for TrackSchematic.
extension TrackSchematic {
    /// Renders the far-edge track's shown run, its hidden windows
    /// behind the edge slot they wait at (#2235).
    var overflowTrack: some View {
        GeometryReader { geo in
            let slots = overflowSlots(geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(slots.indices, id: \.self) { i in
                    // A `last` own-track past the cap IS the
                    // overflow's newest member (#1354), and as
                    // the focus it is the run's last shown slot.
                    SchematicPileTile(
                        isNew: incomingFolds && i == slots.count - 1
                    )
                    .frame(
                        width: slots[i].rect.width,
                        height: slots[i].rect.height
                    )
                    .position(
                        x: slots[i].rect.midX,
                        y: slots[i].rect.midY
                    )
                    .zIndex(slots[i].hidden ? -1 : 0)
                }
            }
        }
    }

    /// One overflow-track window's slot; a hidden one shares the
    /// edge slot it waits behind.
    struct OverflowSlot {
        var rect: CGRect
        var hidden: Bool
    }

    /// The overflow track's windows (always vertical): up to
    /// `trackSpillCapacity` — the stand-in for "fit at the
    /// minimum size", as for the fill rule — share the track, and
    /// the rest wait behind an edge slot, as `ZoneRun` places
    /// them. An incoming window folding in takes the focus, so
    /// the run ends at it and the earlier windows wait behind the
    /// first slot. Only reached with at least one window to draw.
    func overflowSlots(_ size: CGSize) -> [OverflowSlot] {
        let n = overflowWindows
        let shown = min(LayoutSchematic.trackSpillCapacity, n)
        let head = incomingFolds ? n - shown : 0
        let g: CGFloat = 3
        let rowH = max(
            8,
            (size.height - g * CGFloat(max(0, shown - 1)))
                / CGFloat(max(1, shown))
        )
        return (0..<n).map { index in
            let row = min(max(index - head, 0), shown - 1)
            return OverflowSlot(
                rect: CGRect(
                    x: 0,
                    y: CGFloat(row) * (rowH + g),
                    width: size.width,
                    height: rowH
                ),
                hidden: index < head || index >= head + shown
            )
        }
    }
}
