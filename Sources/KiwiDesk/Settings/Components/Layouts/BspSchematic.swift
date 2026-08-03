import KiwiDeskCore
import SwiftUI

/// The BSP schematic (#125): one wide frame showing `windows`
/// windows — the established ones plus the incoming
/// **new-window tile** — tiled by the *real* `BspLayout`, so the
/// picture can never drift from what the engine actually does. A
/// wide frame is deliberate: the split *strategy* only becomes
/// visible once a region has been cut enough times that "cut the
/// longer side" and "alternate H/V" diverge, which needs a
/// widescreen and several windows — which is also why the count
/// is the preview's slider (turn 10) rather than a constant: the
/// two strategies are indistinguishable at two windows and
/// unmistakable at eight.
///
/// Window 2 is the focused one (thick stroke); the last window is
/// inserted at the array index the `placement` rule dictates and
/// drawn as the dense `+` tile, so "first / last / before / after
/// focused" reads straight off the frame.
struct BspSchematic: View {
    let splitRatioH: Double
    let splitRatioV: Double
    let strategy: BspParams.Strategy
    let placement: SpawnPlacement
    /// Windows on screen, the incoming one included.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    /// At the tile scale the frame is the strip's, not this
    /// schematic's — see `SchematicScale`, which argues why the
    /// 3:1 widescreen is a panel-only affordance.
    private var frameWidth: CGFloat? { scale.width }
    private var frameHeight: CGFloat {
        scale == .tile ? scale.height : 260
    }

    /// The established windows: everything but the incoming one.
    /// Focus is window 2 where there is one — with a single
    /// established window it is that window, so the relative
    /// placements still have a reference.
    private var base: [WindowID] {
        (1...max(1, windows - 1)).map { WindowID(UInt32($0)) }
    }
    var focused: WindowID {
        base.count >= 2 ? WindowID(2) : WindowID(1)
    }
    /// Above every established id, whatever the count.
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
            .animation(LayoutSchematic.damping, value: splitRatioH)
            .animation(LayoutSchematic.damping, value: splitRatioV)
            .animation(LayoutSchematic.damping, value: strategy)
            .animation(LayoutSchematic.damping, value: placement)
            .animation(LayoutSchematic.damping, value: windows)
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
                        // `.position` places the tile's centre at
                        // an absolute point in the frame's own
                        // coordinate space (top-left origin) —
                        // unlike `.offset`, which shifts from a
                        // tile's centred natural spot in the ZStack.
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

    /// The windows in array order, with the new one spliced in
    /// where `placement` opens it — asked of the engine through
    /// `SchematicPlacement` rather than reproduced here (#702).
    /// Tiles are keyed by id, so the focus follows its window
    /// when the splice pushes it along.
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

    /// Runs the production `BspLayout` over the windows in the
    /// canvas. Tiny inner gaps separate the tiles; a ~1 pt
    /// minimum keeps the overlap fallback out of the preview —
    /// the fallback is a real behaviour, but it is the *minimum
    /// window size*'s story, and firing it here would make a
    /// dozen-window preview claim BSP piles when the screen it
    /// stands for would not.
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
