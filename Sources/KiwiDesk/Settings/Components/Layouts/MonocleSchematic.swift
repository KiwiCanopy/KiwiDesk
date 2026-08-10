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
    /// Windows on screen. Monocle's fill logic is that there
    /// isn't any — every window is full-screen — so the count
    /// changes the DEPTH of the fan and nothing else, which is
    /// the honest answer to "what do more windows do here".
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    private var horizontal: Bool { orientation == .horizontal }

    /// Cards drawn behind the focused one. Capped so the fan
    /// stays a fan: past four the offsets march off the canvas
    /// and say nothing a fourth card didn't.
    var depth: Int { min(max(windows, 1), 4) - 1 }

    var body: some View {
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            ZStack {
                cards
                chevrons
            }
            .animation(LayoutSchematic.damping, value: orientation)
            .animation(LayoutSchematic.damping, value: windows)
        }
    }

    /// Back-to-front fan: the focused card fills, the others peek
    /// behind it toward the top-trailing corner.
    private var cards: some View {
        ZStack {
            ForEach(
                Array((0...depth).reversed()),
                id: \.self
            ) { level in
                card(front: level == 0)
                    .padding(10)
                    .offset(
                        x: CGFloat(level) * 5,
                        y: -CGFloat(level) * 5
                    )
            }
        }
    }

    private func card(front: Bool) -> some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(
                front
                    ? LayoutSchematic.fill
                    : SettingsTheme.ink2.opacity(0.10)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    front
                        ? LayoutSchematic.stroke
                        : SettingsTheme.ink2.opacity(0.4),
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
