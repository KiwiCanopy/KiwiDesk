import KiwiDeskCore
import SwiftUI

/// Monocle layout schematic preview (#125, #881).
struct MonocleSchematic: View {
    let orientation: MonocleParams.Orientation
    var hideStyle: MonocleParams.HideStyle = .stack
    @Environment(\.schematicFocusStroke) private var focusStroke
    @Environment(\.schematicPalette) private var palette
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Restage animation damping (#1069, `LayoutSchematic.damping`).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    private var horizontal: Bool { orientation == .horizontal }
    private var parked: Bool { hideStyle == .park }

    /// Depth of cards drawn behind focused window.
    var depth: Int { min(max(windows, 1), 4) - 1 }

    /// Visible fan depth; collapsed under park hide style (#881).
    var fanDepth: Int { parked ? 0 : depth }

    /// Whether parked mini pile is rendered at panel scale
    /// (#753). Internal, not private, so the caption guard asserts
    /// the arithmetic rather than scanning for the input.
    var drawsParkedPile: Bool {
        parked && scale == .panel && depth > 0
    }

    var body: some View {
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            ZStack(alignment: .bottomTrailing) {
                cards
                if drawsParkedPile {
                    parkedPile
                }
                chevrons
            }
            .animation(damping, value: orientation)
            .animation(damping, value: windows)
            .animation(damping, value: hideStyle)
        }
    }

    private var cards: some View {
        ZStack {
            ForEach(
                Array((0...fanDepth).reversed()),
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

    /// Parked window pile schematic at bottom corner (#881).
    private var parkedPile: some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(
                Array((0..<depth).reversed()),
                id: \.self
            ) { level in
                card(front: false)
                    .frame(width: 16, height: 11)
                    .offset(
                        x: CGFloat(level) * -2,
                        y: CGFloat(level) * -2
                    )
            }
        }
        .padding(14)
    }

    private func fill(front: Bool) -> Color {
        SchematicCardColors.fill(front: front, palette: palette)
    }

    private func edge(front: Bool) -> Color {
        SchematicCardColors.edge(
            front: front,
            focusStroke: focusStroke,
            palette: palette
        )
    }

    private func card(front: Bool) -> some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(fill(front: front))
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    // The front card IS monocle's focus mark, so
                    // it consults the honesty stroke like every
                    // active tile (code review 2026-08-10).
                    edge(front: front),
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

    /// Caption string for schematic (`LayoutSchematicCaptionTests`).
    var caption: String {
        switch (parked, horizontal) {
        case (false, true):
            return L(
                "layout.schematic.monocle.caption_h",
                "All windows fill the screen; new ones come to "
                    + "the front, and focus cycles left/right."
            )
        case (false, false):
            return L(
                "layout.schematic.monocle.caption_v",
                "All windows fill the screen; new ones come to "
                    + "the front, and focus cycles up/down."
            )
        case (true, true):
            return L(
                "layout.schematic.monocle.caption_park_h",
                "The focused window fills the screen and the "
                    + "rest park in a corner; new ones come to "
                    + "the front, and focus snaps left/right."
            )
        case (true, false):
            return L(
                "layout.schematic.monocle.caption_park_v",
                "The focused window fills the screen and the "
                    + "rest park in a corner; new ones come to "
                    + "the front, and focus snaps up/down."
            )
        }
    }

    var axLabel: String {
        parked
            ? L(
                "layout.schematic.monocle.ax_park",
                "Monocle preview: one window fills the screen; "
                    + "the others park in a corner, and focus "
                    + "switches instantly."
            )
            : L(
                "layout.schematic.monocle.ax",
                "Monocle preview: one window fills the screen; "
                    + "focus cycles through the others."
            )
    }
}
