import KiwiDeskCore
import SwiftUI

/// The Monocle schematic (#125): Monocle has no tiling geometry
/// (every window fills the screen), so this doesn't draw a
/// layout — it draws the **navigation model**, which is Monocle's
/// one real knob. A fan of full-screen cards with the focused one
/// in front, plus cycle chevrons along the `orientation` axis,
/// says "one window visible, the rest behind it, focus cycles
/// this way." That resolves the "why is this the one blank tab"
/// inconsistency honestly, without inventing spatial content.
struct MonocleSchematic: View {
    let orientation: MonocleParams.Orientation

    private var horizontal: Bool { orientation == .horizontal }

    var body: some View {
        SchematicCanvas(caption: caption, axLabel: axLabel) {
            ZStack {
                cards
                chevrons
            }
            .animation(LayoutSchematic.damping, value: orientation)
        }
    }

    /// Back-to-front fan: the focused card fills, the others peek
    /// behind it toward the top-trailing corner.
    private var cards: some View {
        ZStack {
            ForEach([2, 1, 0], id: \.self) { depth in
                card(front: depth == 0)
                    .padding(10)
                    .offset(
                        x: CGFloat(depth) * 5,
                        y: -CGFloat(depth) * 5
                    )
            }
        }
    }

    private func card(front: Bool) -> some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(
                front
                    ? LayoutSchematic.fill
                    : Color.secondary.opacity(0.10)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    front
                        ? LayoutSchematic.stroke
                        : Color.secondary.opacity(0.4),
                    lineWidth: front ? 1.5 : 1
                )
            )
    }

    @ViewBuilder
    private var chevrons: some View {
        Group {
            if horizontal {
                HStack {
                    Image(systemName: "chevron.left")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            } else {
                VStack {
                    Image(systemName: "chevron.up")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(2)
    }

    private var caption: String {
        horizontal
            ? L(
                "layout.schematic.monocle.caption_h",
                "All windows fill the screen; new ones come to "
                    + "the front, and focus cycles left/right."
            )
            : L(
                "layout.schematic.monocle.caption_v",
                "All windows fill the screen; new ones come to "
                    + "the front, and focus cycles up/down."
            )
    }

    private var axLabel: String {
        L(
            "layout.schematic.monocle.ax",
            "Monocle preview: one window fills the screen; "
                + "focus cycles through the others."
        )
    }
}
