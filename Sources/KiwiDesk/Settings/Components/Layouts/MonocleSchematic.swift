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
    /// Tour story phase (`SchematicMotion.arrival`, #1750, #2099).
    var arrival: Double = 0

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.schematicRestage) private var restage

    /// Restage animation damping (#1069, `\.schematicRestage`).
    private var damping: Animation? {
        reduceMotion ? nil : restage
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
                leavingCard
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
                fanCard(level: level)
                    .padding(10)
                    .opacity(opacity(ofLevel: level))
                    .offset(
                        x: drawnLevel(level) * 5,
                        y: -drawnLevel(level) * 5
                    )
            }
        }
    }

    /// The card resting at `level`: the front one crossfades from
    /// a back card to the focus mark as it arrives (#2099).
    private func fanCard(level: Int) -> some View {
        ZStack {
            card(front: false)
                .opacity(level == 0 ? arrival : 1)
            if level == 0 {
                card(front: true).opacity(focusWeight)
            }
        }
    }

    /// How much of the focus mark the arriving card wears: none
    /// while the window it replaces is in front, all at rest.
    var focusWeight: Double { 1 - arrival }

    /// Where the card resting at `level` is drawn, in fan steps:
    /// one step further back while the story's step is still to
    /// come, so the fan steps forward as the front card fades.
    /// The backmost card fades in where it rests instead.
    func drawnLevel(_ level: Int) -> CGFloat {
        guard fanDepth > 0, level < fanDepth else {
            return CGFloat(level)
        }
        return CGFloat(level) + CGFloat(arrival)
    }

    /// The backmost card of a fan appears as the fan steps
    /// forward; every other card is always drawn.
    func opacity(ofLevel level: Int) -> Double {
        fanDepth > 0 && level == fanDepth ? 1 - arrival : 1
    }

    /// The window the story's step replaces: in front at the
    /// start, gone at rest — fill and focus stroke together — so
    /// the rest frame draws nothing here.
    private var leavingCard: some View {
        card(front: true)
            .padding(10)
            .opacity(arrival)
            .allowsHitTesting(false)
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
                "One window at a time; the rest wait behind it. "
                    + "Stepping left/right brings the next to the "
                    + "front, and nothing moves."
            )
        case (false, false):
            return L(
                "layout.schematic.monocle.caption_v",
                "One window at a time; the rest wait behind it. "
                    + "Stepping up/down brings the next to the "
                    + "front, and nothing moves."
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
                "Monocle preview: one window fills the screen "
                    + "and the others wait behind it; focus "
                    + "brings the next to the front without "
                    + "moving any window."
            )
    }
}
