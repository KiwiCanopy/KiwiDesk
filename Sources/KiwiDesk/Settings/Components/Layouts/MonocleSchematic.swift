import KiwiDeskCore
import SwiftUI

/// The Monocle schematic (#125): Monocle splits no geometry —
/// the focused window fills the screen — so this doesn't draw a
/// layout: it draws the **navigation model** plus, since #881,
/// where the hidden members rest. A fan of full-screen cards
/// with the focused one in front, plus cycle chevrons along the
/// `orientation` axis, says "one window visible, the rest
/// behind it, focus cycles this way"; under `hide_style = park`
/// the fan collapses to the focused card and the hidden members
/// read as an iconic pile at a bottom corner instead. That
/// resolves the "why is this the one blank tab" inconsistency
/// honestly, without inventing spatial content.
struct MonocleSchematic: View {
    let orientation: MonocleParams.Orientation
    var hideStyle: MonocleParams.HideStyle = .stack
    @Environment(\.schematicFocusStroke) private var focusStroke
    @Environment(\.schematicPalette) private var palette
    /// Windows on screen. Monocle's fill logic is that there
    /// isn't any — every window is full-screen — so the count
    /// changes the DEPTH of the fan and nothing else, which is
    /// the honest answer to "what do more windows do here".
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// The restage damping, gated on Reduce Motion (#1069) —
    /// the arrangement still redraws, it just stops travelling.
    /// The ternary is spelled here rather than folded into
    /// `LayoutSchematic.damping`; that file says why.
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    private var horizontal: Bool { orientation == .horizontal }
    private var parked: Bool { hideStyle == .park }

    /// Cards drawn behind the focused one. Capped so the fan
    /// stays a fan: past four the offsets march off the canvas
    /// and say nothing a fourth card didn't.
    var depth: Int { min(max(windows, 1), 4) - 1 }

    /// Cards in the BEHIND fan. Zero under `park` (#881): the
    /// back cards depict exactly the arrangement park removes,
    /// and a preview that keeps them while the draft says park
    /// teaches the user the setting did nothing. The hidden
    /// members move to the corner pile below instead.
    var fanDepth: Int { parked ? 0 : depth }

    /// Whether the parked corner pile is on the frame: `park`
    /// at `.panel` with members to park. A thumbnail leaves it
    /// undrawn (#753) and a lone window parks nothing.
    /// Internal, not private, so the caption guard asserts the
    /// arithmetic rather than scanning for the input.
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
                // The parked pile is an ICONIC mark, drawn at
                // `.panel` and left undrawn at `.tile` (#753):
                // a sliver fact is unreadable at thumbnail
                // scale, and the engine picks the real corner
                // per screen (`optimalHideCorner`), so the
                // drawing claims a corner, not THE corner.
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

    /// Back-to-front fan: the focused card fills, the others peek
    /// behind it toward the top-trailing corner.
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

    /// The parked members under `park` (#881): a small pile of
    /// card minis at a bottom corner — the fan's own vocabulary
    /// at pile scale, driven by the same count-derived `depth`
    /// as the fan so the slider still answers here.
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

    /// The family's fallback ladder, stated once in
    /// `SchematicCardColors` — the two card-fan schematics drew
    /// byte-identical copies of it for a day, and what they were
    /// copying was the rule rather than a value.
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
                    // Monocle's front card IS its focus mark,
                    // so it consults the honesty stroke like
                    // every active tile — the strip must not
                    // show two focus colours disagreeing about
                    // what the colour means (code review
                    // 2026-08-10).
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

    /// Keyed on BOTH controls that change what the frame shows
    /// (`LayoutSchematicCaptionTests`): one string spanning the
    /// hide-style options would state the park fact under
    /// `stack`, over a fan the park frame never draws — and the
    /// instant switch is a motion fact only the words can carry.
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
