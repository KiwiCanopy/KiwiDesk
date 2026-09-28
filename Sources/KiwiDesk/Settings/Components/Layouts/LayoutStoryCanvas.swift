import KiwiDeskCore
import SwiftUI

/// A tiling story's frame (#1750): the engine's arrangement of
/// `count` windows (`LayoutStoryArrangement`), drawn with the
/// schematics' tiles on their canvas. The focused window carries
/// the ring; the newest window pops up in its own slot while the
/// others make room. It draws no `+` slot — a story shows a
/// window arriving, not where the next one would.
struct LayoutStoryCanvas: View {
    let mode: LayoutMode
    let settings: TilingSettings
    let count: Int
    let scale: SchematicScale
    let axLabel: String
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: "",
            axLabel: axLabel,
            showsCaption: false
        ) {
            // Clipped at the screen edge: a piled window hangs
            // past it on a real screen too.
            GeometryReader { geo in
                tiles(in: geo.size)
            }
            .clipped()
        }
        .environment(
            \.schematicFocusStroke,
            LayoutSchematicView.focusStroke(
                settings,
                onPlate: palette != nil
            )
        )
    }

    private func tiles(in size: CGSize) -> some View {
        let space = LayoutStoryArrangement.space(
            mode,
            settings: settings,
            count: count
        )
        let frames = LayoutStoryArrangement.frames(
            mode,
            settings: settings,
            count: count,
            in: size
        )
        return ZStack(alignment: .topLeading) {
            ForEach(space.windows, id: \.raw) { id in
                if let rect = frames[id] {
                    SchematicTile(active: id == space.focused)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .transition(Self.arrival(of: rect, in: size))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Pops a window up from the centre of its own slot.
    /// `.position` stretches the tile's view over the canvas, so
    /// the anchor is the slot's centre in canvas units.
    static func arrival(of rect: CGRect, in size: CGSize) -> AnyTransition {
        let anchor = UnitPoint(
            x: rect.midX / max(size.width, 1),
            y: rect.midY / max(size.height, 1)
        )
        return .modifier(
            active: ArrivalPop(amount: 0, anchor: anchor),
            identity: ArrivalPop(amount: 1, anchor: anchor)
        )
    }
}

/// The scale and opacity an arriving window pops up through.
private struct ArrivalPop: ViewModifier {
    let amount: CGFloat
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.2 + 0.8 * amount, anchor: anchor)
            .opacity(amount)
    }
}
