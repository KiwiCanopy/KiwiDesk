import KiwiDeskCore
import SwiftUI

/// The Stack schematic (#125): a master column sized by the staged
/// master ratio, beside a four-window stack column that shows the
/// overflow style *directly* rather than with a stand-in glyph —
/// `cascade_overflow` piles only the last two windows, `cascade_all`
/// piles the whole column so just the top edges peek. Focus sits on
/// the first stack window, so the new-window placement (first /
/// last / before / after focused) reads off which slot the dense
/// `+` tile takes.
///
/// The piled tiles are drawn **opaque** (each with its own solid
/// base), so overlapping them never sums the accent alpha into
/// muddy bands — the front (last) window carries the dominant
/// colour and the buried ones read as lighter title-bar slivers
/// behind it. Hand-drawn, unlike the BSP schematic which drives the
/// real `BspLayout`: the engine's 40 pt cascade offset would throw
/// tiles off this mini canvas, so the offset is scaled down here.
struct StackSchematic: View {
    let masterCount: Int
    let masterRatio: Double
    let overflowStyle: StackParams.OverflowStyle
    let placement: SpawnPlacement

    /// Existing windows before the new one arrives. Five, because
    /// the new window always lands in the stack zone here (with one
    /// master, even placement=first displaces the old master into
    /// it), so the stack settles at a steady six: a deep pile for
    /// `cascade_all`, a fixed 3 tiled + 3 piled for
    /// `cascade_overflow`.
    private static let stackWindows = 5
    /// Tiled windows kept above the cascade-overflow pile; the rest
    /// (the surplus) pile.
    private static let overflowTiled = 3
    /// Scaled-down title-bar reveal (the engine uses 40 pt).
    private static let cascadeOffset: CGFloat = 9

    private var masters: Int { max(1, masterCount) }
    private let newWindow = WindowID(99)

    /// The first stack window is the focused one.
    private var focused: WindowID {
        WindowID(UInt32(masters + 1))
    }

    /// The windows in array order with the new one spliced in per
    /// `placement` (focus = first stack window) — the same rule as
    /// `SpaceModel.insert`. Partitioning at `masters` then sorts
    /// them into the two columns exactly as `StackLayout` does.
    private var order: [WindowID] {
        var w = (1...(masters + Self.stackWindows))
            .map { WindowID(UInt32($0)) }
        switch placement {
        case .first:
            w.insert(newWindow, at: 0)
        case .last:
            w.append(newWindow)
        case .beforeFocused:
            if let i = w.firstIndex(of: focused) {
                w.insert(newWindow, at: i)
            }
        case .afterFocused:
            if let i = w.firstIndex(of: focused) {
                w.insert(newWindow, at: i + 1)
            }
        }
        return w
    }

    private var masterWins: [WindowID] {
        Array(order.prefix(masters))
    }

    private var stackWins: [WindowID] {
        Array(order.dropFirst(masters))
    }

    var body: some View {
        SchematicCanvas(caption: caption, axLabel: axLabel) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    masterColumn
                        .frame(width: masterWidth(geo.size.width))
                    stackColumn
                }
            }
            .animation(LayoutSchematic.damping, value: masterCount)
            .animation(LayoutSchematic.damping, value: masterRatio)
            .animation(
                LayoutSchematic.damping,
                value: overflowStyle
            )
            .animation(LayoutSchematic.damping, value: placement)
        }
    }

    private func masterWidth(_ total: CGFloat) -> CGFloat {
        max(6, (total - 3) * CGFloat(masterRatio))
    }

    // MARK: - Master column

    /// The master zone stacked evenly, capped for legibility with a
    /// "+N" chip when the master count outgrows the mini-canvas.
    private var masterColumn: some View {
        let visible = min(masterWins.count, 4)
        let hidden = masterWins.count - visible
        return VStack(spacing: 3) {
            ForEach(0..<visible, id: \.self) { i in
                ZStack(alignment: .bottomTrailing) {
                    tile(for: masterWins[i])
                    if i == visible - 1, hidden > 0 {
                        SchematicMoreChip(hidden: hidden)
                            .padding(2)
                    }
                }
            }
        }
    }

    // MARK: - Stack column

    /// One slot per stack window, top-to-bottom. Draw order is array
    /// order, so a pile's lower, later tiles land on top — the front
    /// window covers the buried ones except their top edge.
    private struct Slot {
        var rect: CGRect
        var piled: Bool
        var front: Bool
    }

    private var stackColumn: some View {
        GeometryReader { geo in
            let slots = stackSlots(in: geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(slots.indices, id: \.self) { i in
                    stackTile(
                        for: stackWins[i],
                        slot: slots[i]
                    )
                    .frame(
                        width: slots[i].rect.width,
                        height: slots[i].rect.height
                    )
                    .position(
                        x: slots[i].rect.midX,
                        y: slots[i].rect.midY
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// `cascade_all` piles every window; `cascade_overflow` tiles
    /// the run and piles the last `overflowPile` (the surplus).
    /// Piled tiles keep full height but overlap by `cascadeOffset`,
    /// so only their top edge shows above the next.
    private func stackSlots(in size: CGSize) -> [Slot] {
        let n = stackWins.count
        let w = size.width
        let h = size.height
        let off = Self.cascadeOffset
        if overflowStyle == .cascadeAll {
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

    @ViewBuilder
    private func stackTile(
        for id: WindowID,
        slot: Slot
    ) -> some View {
        if slot.piled {
            pileTile(id: id, front: slot.front)
        } else {
            tile(for: id)
        }
    }

    /// An opaque cascade tile: a solid base so stacking never sums
    /// the accent alpha into dark bands, then the *same* accent fill
    /// every other tile uses. The overlapping borders — not colour —
    /// separate the piled windows from one another.
    private func pileTile(id: WindowID, front: Bool) -> some View {
        let corner = LayoutSchematic.corner
        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(nsColor: .textBackgroundColor))
            RoundedRectangle(cornerRadius: corner)
                .fill(LayoutSchematic.fill)
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(
                    LayoutSchematic.stroke,
                    lineWidth: id == focused ? 2 : 1
                )
            if id == newWindow {
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(2)
            }
        }
    }

    @ViewBuilder
    private func tile(for id: WindowID) -> some View {
        if id == newWindow {
            SchematicNewWindow()
        } else {
            SchematicTile(active: id == focused)
        }
    }

    private var caption: String {
        switch overflowStyle {
        case .cascadeOverflow:
            return L(
                "layout.schematic.stack.caption_overflow",
                "Master column beside the stack; when the stack "
                    + "fills, the surplus piles at the bottom."
            )
        case .cascadeAll:
            return L(
                "layout.schematic.stack.caption_all",
                "Master column beside the stack; when the stack "
                    + "fills, the whole column piles so only the "
                    + "top edges show."
            )
        }
    }

    private var axLabel: String {
        L(
            "layout.schematic.stack.ax",
            "Stack preview: %1$d master windows, master ratio "
                + "%2$d percent; the plus tile is where the next "
                + "window lands.",
            masterCount,
            SchematicMath.pct(masterRatio)
        )
    }
}
