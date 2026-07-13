import KiwiDeskCore
import SwiftUI

/// The BSP schematic (#125): one wide frame showing five windows —
/// four already open plus the incoming **new-window tile** — tiled
/// by the *real* `BspLayout`, so the picture can never drift from
/// what the engine actually does. A wide frame is deliberate: the
/// split *strategy* only becomes visible once a region has been cut
/// enough times that "cut the longer side" and "alternate H/V"
/// diverge, which needs a widescreen and several windows.
///
/// Window 2 is the focused one (thick stroke); the fifth window is
/// inserted at the array index the `placement` rule dictates and
/// drawn as the dense `+` tile, so "first / last / before / after
/// focused" reads straight off the frame.
struct BspSchematic: View {
    let splitRatioH: Double
    let splitRatioV: Double
    let strategy: BspParams.Strategy
    let placement: SpawnPlacement

    /// A 3:1 mini-widescreen — wide enough that the longer-side
    /// strategy cuts vertically twice before it turns horizontal,
    /// which is exactly where it parts ways with alternating.
    private static let width: CGFloat = 300
    private static let height: CGFloat = 104

    /// The four established windows; window 2 (index 1) is focused.
    private let base = [1, 2, 3, 4].map { WindowID(UInt32($0)) }
    private let focused = WindowID(2)
    private let newWindow = WindowID(5)

    var body: some View {
        SchematicCanvas(
            width: Self.width,
            height: Self.height,
            caption: caption,
            axLabel: axLabel
        ) {
            GeometryReader { geo in
                tiles(in: geo.size)
            }
            .animation(LayoutSchematic.damping, value: splitRatioH)
            .animation(LayoutSchematic.damping, value: splitRatioV)
            .animation(LayoutSchematic.damping, value: strategy)
            .animation(LayoutSchematic.damping, value: placement)
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

    /// The five windows in array order, with the new one spliced in
    /// per `placement` — the same rule as `SpaceModel.insert`
    /// (kept in step with it; small, self-contained duplication).
    private var order: [WindowID] {
        var windows = base
        switch placement {
        case .first:
            windows.insert(newWindow, at: 0)
        case .last:
            windows.append(newWindow)
        case .beforeFocused:
            if let i = windows.firstIndex(of: focused) {
                windows.insert(newWindow, at: i)
            }
        case .afterFocused:
            if let i = windows.firstIndex(of: focused) {
                windows.insert(newWindow, at: i + 1)
            }
        }
        return windows
    }

    /// Runs the production `BspLayout` over the five windows in the
    /// mini-canvas. Tiny inner gaps separate the tiles; a ~1 pt
    /// minimum keeps the overlap fallback out of the preview.
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
