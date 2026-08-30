import KiwiDeskCore
import SwiftUI

/// Stack layout schematic preview showing master and stack zones (#125, #222).
struct StackSchematic: View {
    let masterCount: Int
    let masterRatio: Double
    let overflowStyle: StackParams.OverflowStyle
    let masterOrientation: StackParams.Orientation
    let stackPosition: StackParams.StackPosition
    let placement: SpawnPlacement
    /// Total windows drawn including incoming tile.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Restage animation damping gated on Reduce Motion (#1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    /// Derived stack orientation matching engine
    /// (`StackSchematic+Slots.swift`).
    var stackOrientation: StackParams.Orientation {
        stackPosition.stackOrientation
    }

    /// Tiled windows count before cascade overflow kicks in.
    static let overflowTiled = 3

    /// Effective master count clamped to window count.
    var masters: Int {
        min(max(1, masterCount), max(1, windows - 1))
    }
    var newWindow: WindowID {
        WindowID(UInt32(max(1, windows - 1) + 1))
    }

    /// Established windows assigned to stack zone.
    var stackWindows: Int {
        max(0, windows - 1 - masters)
    }

    /// Focused window ID for placement reference (#702).
    var focused: WindowID {
        WindowID(UInt32(min(masters + 1, max(1, windows - 1))))
    }

    /// Windows in array order with new window spliced in
    /// (`LayoutSchematicPlacementTests`, #702).
    var order: [WindowID] {
        var w = (1...max(1, masters + stackWindows))
            .map { WindowID(UInt32($0)) }
        let index = SchematicPlacement.splice(
            placement,
            count: w.count,
            focus: w.firstIndex(of: focused) ?? 0
        ).incoming
        w.insert(newWindow, at: index)
        return w
    }

    /// Master zone windows (`LayoutSchematicZoneTests`, #707).
    var masterWins: [WindowID] {
        Array(order.prefix(masters))
    }

    /// Master tiles in display order (#313, `StackLayout.mirrorsMasterZone`).
    var masterDisplay: [WindowID] {
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
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            GeometryReader { geo in
                zones(in: geo.size)
            }
            .animation(damping, value: windows)
            .animation(damping, value: masterCount)
            .animation(damping, value: masterRatio)
            .animation(damping, value: overflowStyle)
            .animation(damping, value: masterOrientation)
            .animation(damping, value: stackPosition)
            .animation(damping, value: placement)
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

    /// Slot geometry and pile state per stack window.
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
            SchematicPileTile(
                active: id == focused,
                isNew: id == newWindow
            )
        } else {
            tile(for: id)
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

    /// Speaks `masters`, not the staged `masterCount`: the count
    /// is clamped to the windows on screen, so reading the
    /// setting aloud would claim ten masters over a frame
    /// drawing one.
    private var axLabel: String {
        L(
            "layout.schematic.stack.ax",
            "Stack preview: %1$d master windows, master ratio "
                + "%2$d percent; the plus tile is where the next "
                + "window lands.",
            masters,
            SchematicMath.pct(masterRatio)
        )
    }
}
