import KiwiDeskCore
import SwiftUI

/// Interactive BSP layout schematic preview (`BspLayout`, #125).
struct BspSchematic: View {
    let splitRatioH: Double
    let splitRatioV: Double
    let strategy: BspParams.Strategy
    let placement: SpawnPlacement
    /// Windows on screen, the incoming one included.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Restage animation damping gated on Reduce Motion
    /// (`LayoutSchematic.damping`, #1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    private var frameWidth: CGFloat? { scale.width }
    private var frameHeight: CGFloat {
        scale == .tile ? scale.height : 260
    }

    private var base: [WindowID] {
        (1...max(1, windows - 1)).map { WindowID(UInt32($0)) }
    }
    var focused: WindowID {
        base.count >= 2 ? WindowID(2) : WindowID(1)
    }
    var newWindow: WindowID {
        WindowID(UInt32(max(1, windows - 1) + 1))
    }

    var body: some View {
        SchematicCanvas(
            width: frameWidth,
            height: frameHeight,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            GeometryReader { geo in
                tiles(in: geo.size)
            }
            .animation(damping, value: splitRatioH)
            .animation(damping, value: splitRatioV)
            .animation(damping, value: strategy)
            .animation(damping, value: placement)
            .animation(damping, value: windows)
        }
    }

    @ViewBuilder
    private func tiles(in size: CGSize) -> some View {
        let frames = layout(in: size)
        ZStack(alignment: .topLeading) {
            ForEach(order, id: \.raw) { id in
                if let rect = frames[id] {
                    tile(for: id)
                        .frame(
                            width: rect.width,
                            height: rect.height
                        )
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func tile(for id: WindowID) -> some View {
        if id == newWindow {
            SchematicNewWindow()
        } else {
            SchematicTile(active: id == focused)
        }
    }

    /// Windows in array order with incoming window spliced in
    /// (`SchematicPlacement`, #702).
    var order: [WindowID] {
        var windows = base
        let index = SchematicPlacement.splice(
            placement,
            count: windows.count,
            focus: windows.firstIndex(of: focused) ?? 0
        ).incoming
        windows.insert(newWindow, at: index)
        return windows
    }

    /// Computes window rects using production layout
    /// (`BspLayout`, `BspParams`).
    private func layout(in size: CGSize) -> [WindowID: CGRect] {
        var params = BspParams()
        params.strategy = strategy
        params.splitRatioH = splitRatioH
        params.splitRatioV = splitRatioV
        let context = LayoutContext(
            bounds: CGRect(origin: .zero, size: size),
            gaps: Gaps(
                outer: .init(top: 0, bottom: 0, left: 0, right: 0),
                inner: .init(horizontal: 3, vertical: 3)
            ),
            focused: focused,
            minWindowSize: 1,
            bsp: params
        )
        return BspLayout().calculateGeometry(
            for: order,
            in: context
        )
    }

    private var caption: String {
        switch strategy {
        case .longestSide:
            return L(
                "layout.schematic.bsp.caption_longest",
                "Each split cuts the longer side; the + tile is "
                    + "where the next window opens."
            )
        case .alternating:
            return L(
                "layout.schematic.bsp.caption_alternating",
                "Splits alternate horizontal then vertical; the + "
                    + "tile is where the next window opens."
            )
        }
    }

    private var axLabel: String {
        L(
            "layout.schematic.bsp.ax",
            "BSP preview: width ratio %1$d percent, height "
                + "ratio %2$d percent; the plus tile is where "
                + "the next window lands.",
            SchematicMath.pct(splitRatioH),
            SchematicMath.pct(splitRatioV)
        )
    }
}
