import KiwiDeskCore
import SwiftUI

/// The layout-cycle plate (#2144): the user's cycle list as a
/// ring — first entry at 12 o'clock, clockwise — with the current
/// layout large in the centre, its slot left empty, and its name
/// under it. Each symbol is one view, so a step moves the
/// incoming one from its slot to the centre and the outgoing one
/// back out (the shared element). `cycle_mode` lands only on a
/// list entry, so the centre is always one of the ring's own.
struct ModeCueView: View {
    let cue: ModeCycleCue
    /// KiwiHub's glass, the Fill with it under the toggle (#2569).
    let glass: PanelGlass

    /// The panel's room height, so the plate fills it.
    static let side = CuePlateModel.tallSide
    /// Raised off the middle to leave the caption its line.
    static let centre = CGPoint(x: side / 2, y: side / 2 - 12)
    static let radius: CGFloat = 44
    static let symbolSize: CGFloat = 40
    static let slotSize: CGFloat = 13
    static let captionY = side - 20

    var body: some View {
        ZStack {
            ForEach(cue.cycle, id: \.self) { mode in
                symbol(mode, current: mode == cue.current)
                    .position(
                        mode == cue.current
                            ? Self.centre : Self.slot(of: mode, in: cue.cycle)
                    )
            }
            caption
        }
        .frame(width: Self.side, height: Self.side)
        .panelGlassChrome(
            in: RoundedRectangle(
                cornerRadius: CuePlateModel.corner,
                style: .continuous
            ),
            glass: glass,
            fallback: AnyShapeStyle(.regularMaterial)
        )
    }

    /// Drawn at the centre's size and scaled down in a slot, so a
    /// step animates one scale rather than swapping fonts.
    private func symbol(_ mode: LayoutMode, current: Bool) -> some View {
        Image(systemName: mode.symbol)
            .font(.system(size: Self.symbolSize))
            .frame(width: 50, height: 50)
            .scaleEffect(current ? 1 : Self.slotSize / Self.symbolSize)
            .opacity(current ? 1 : 0.5)
    }

    /// The name crossfades on a step. Primary ink: it is the
    /// plate's answer, not a side note like the Desktop plate's
    /// profile line.
    private var caption: some View {
        let name = cue.current.displayName
        return Text(verbatim: name)
            .font(Font(CuePlateModel.captionFont))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: Self.side - 16)
            .id(cue.current)
            .transition(.opacity)
            .position(x: Self.centre.x, y: Self.captionY)
    }

    /// `mode`'s place on the ring: the first entry at 12 o'clock,
    /// clockwise in list order.
    static func slot(of mode: LayoutMode, in cycle: [LayoutMode]) -> CGPoint {
        let index = cycle.firstIndex(of: mode) ?? 0
        let angle =
            -Double.pi / 2
            + 2 * Double.pi * Double(index) / Double(max(cycle.count, 1))
        return CGPoint(
            x: centre.x + radius * CGFloat(cos(angle)),
            y: centre.y + radius * CGFloat(sin(angle))
        )
    }
}
