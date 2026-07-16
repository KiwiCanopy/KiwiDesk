import KiwiDeskCore
import SwiftUI

/// The Stack schematic (#125): a master zone sized by the staged
/// master ratio, beside a six-window stack zone that shows the
/// overflow style *directly* rather than with a stand-in glyph —
/// `cascade_overflow` piles only the surplus windows, `cascade_all`
/// piles the whole zone so just the top edges peek. The #222
/// arrangement fields feed it too: the split follows the staged
/// stack position (which also derives the stack zone's lineup)
/// and the master zone follows its staged orientation (piles
/// keep cascading downward, like the engine).
/// Focus sits on the first stack window, so the new-window
/// placement (first / last / before / after focused) reads off
/// which slot the dense `+` tile takes.
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
    let masterOrientation: StackParams.Orientation
    let stackPosition: StackParams.StackPosition
    let placement: SpawnPlacement

    /// Derived, like the engine (`StackPosition.stackOrientation`).
    /// Internal (not private) for `StackSchematic+Slots.swift`.
    var stackOrientation: StackParams.Orientation {
        stackPosition.stackOrientation
    }

    /// Existing windows before the new one arrives. Five, because
    /// the new window always lands in the stack zone here (with one
    /// master, even placement=first displaces the old master into
    /// it), so the stack settles at a steady six: a deep pile for
    /// `cascade_all`, a fixed 3 tiled + 3 piled for
    /// `cascade_overflow`.
    private static let stackWindows = 5
    /// Tiled windows kept beside the cascade-overflow pile; the
    /// rest (the surplus) pile. Internal (not private), with
    /// the offset below and `stackWins`, for the slot math in
    /// `StackSchematic+Slots.swift`.
    static let overflowTiled = 3
    /// Scaled-down title-bar reveal (the engine uses 40 pt).
    static let cascadeOffset: CGFloat = 9

    private var masters: Int { max(1, masterCount) }
    private let newWindow = WindowID(99)

    /// The first stack window is the focused one.
    private var focused: WindowID {
        WindowID(UInt32(masters + 1))
    }

    /// The windows in array order with the new one spliced in per
    /// `placement` (focus = first stack window) — the same rule as
    /// `SpaceModel.insert`. Partitioning at `masters` then sorts
    /// them into the two zones exactly as `StackLayout` does.
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

    /// Master tiles in render order — mirrored in lockstep with
    /// the engine (#313, `StackLayout.mirrorsMasterZone`), so
    /// the preview never lies about where the boundary master
    /// sits when the stack leads.
    private var masterDisplay: [WindowID] {
        var params = StackParams()
        params.masterOrientation = masterOrientation
        params.stackPosition = stackPosition
        return StackLayout.mirrorsMasterZone(params)
            ? masterWins.reversed()
            : masterWins
    }

    var stackWins: [WindowID] {
        Array(order.dropFirst(masters))
    }

    var body: some View {
        SchematicCanvas(caption: caption, axLabel: axLabel) {
            GeometryReader { geo in
                zones(in: geo.size)
            }
            .animation(LayoutSchematic.damping, value: masterCount)
            .animation(LayoutSchematic.damping, value: masterRatio)
            .animation(
                LayoutSchematic.damping,
                value: overflowStyle
            )
            .animation(
                LayoutSchematic.damping,
                value: masterOrientation
            )
            .animation(
                LayoutSchematic.damping,
                value: stackPosition
            )
            .animation(LayoutSchematic.damping, value: placement)
        }
    }

    /// The master/stack split along the staged position's axis,
    /// mirroring `StackLayout.regions`.
    @ViewBuilder
    private func zones(in size: CGSize) -> some View {
        switch stackPosition {
        case .right:
            HStack(spacing: 3) {
                masterZone.frame(width: masterSpan(size.width))
                stackZone
            }
        case .left:
            HStack(spacing: 3) {
                stackZone
                masterZone.frame(width: masterSpan(size.width))
            }
        case .bottom:
            VStack(spacing: 3) {
                masterZone.frame(height: masterSpan(size.height))
                stackZone
            }
        case .top:
            VStack(spacing: 3) {
                stackZone
                masterZone.frame(height: masterSpan(size.height))
            }
        }
    }

    private func masterSpan(_ total: CGFloat) -> CGFloat {
        max(6, (total - 3) * CGFloat(masterRatio))
    }

    // MARK: - Master zone

    /// The master zone lined up along its staged orientation,
    /// capped for legibility with a "+N" chip when the master
    /// count outgrows the mini-canvas.
    @ViewBuilder
    private var masterZone: some View {
        if masterOrientation == .vertical {
            VStack(spacing: 3) { masterTiles }
        } else {
            HStack(spacing: 3) { masterTiles }
        }
    }

    private var masterTiles: some View {
        let wins = masterDisplay
        let visible = min(wins.count, 4)
        let hidden = wins.count - visible
        return ForEach(0..<visible, id: \.self) { i in
            ZStack(alignment: .bottomTrailing) {
                tile(for: wins[i])
                if i == visible - 1, hidden > 0 {
                    SchematicMoreChip(hidden: hidden)
                        .padding(2)
                }
            }
        }
    }

    // MARK: - Stack zone

    /// One slot per stack window, in array order. Draw order is
    /// array order, so a pile's later tiles land on top — the
    /// front window covers the buried ones except their top edge.
    struct Slot {
        var rect: CGRect
        var piled: Bool
        var front: Bool
    }

    private var stackZone: some View {
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
                "Master zone and stack zone; when the stack "
                    + "fills, the surplus piles up."
            )
        case .cascadeAll:
            return L(
                "layout.schematic.stack.caption_all",
                "Master zone and stack zone; when the stack "
                    + "fills, the whole zone piles so only the "
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
