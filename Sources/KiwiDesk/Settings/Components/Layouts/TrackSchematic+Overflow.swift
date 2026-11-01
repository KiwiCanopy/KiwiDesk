import KiwiDeskCore
import SwiftUI

/// Overflow track layout and slot geometry for TrackSchematic.
extension TrackSchematic {
    /// Renders the far-edge track's shown run, its hidden windows
    /// behind the edge slot they wait at under its overflow mark
    /// (#2235, #2864).
    var overflowTrack: some View {
        GeometryReader { geo in
            let laid = overflowRun(geo.size)
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
                if let laid {
                    SchematicOverflowMarks(
                        laid: laid,
                        bounds: CGRect(origin: .zero, size: geo.size)
                    )
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
        guard let laid = overflowRun(size) else { return [] }
        return laid.rects.enumerated().map { index, rect in
            OverflowSlot(
                rect: rect,
                hidden: !laid.run.visible.contains(index)
            )
        }
    }

    /// The overflow track's run and every member's rect in it; nil
    /// with no window to draw.
    func overflowRun(_ size: CGSize) -> SchematicLaidRun? {
        let n = overflowWindows
        guard n > 0 else { return nil }
        let shown = min(LayoutSchematic.trackSpillCapacity, n)
        let g: CGFloat = 3
        let rowH = max(
            8,
            (size.height - g * CGFloat(max(0, shown - 1)))
                / CGFloat(max(1, shown))
        )
        // The engine's own run (`ZoneRun`, gui.md #702), over
        // floors a hair under the row so exactly `shown` fit.
        let floors = Array(repeating: rowH - 0.01, count: n)
        let run = ZoneRun.resolve(
            floors: floors,
            span: size.height,
            gap: g,
            head: nil,
            focus: incomingFolds ? n - 1 : nil
        )
        let rects = run.frames(
            floors: floors,
            weights: Array(repeating: 1, count: n),
            in: CGRect(origin: .zero, size: size),
            vertical: true,
            gap: g
        )
        return SchematicLaidRun(run: run, rects: rects, vertical: true)
    }
}
