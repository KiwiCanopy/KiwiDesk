import KiwiDeskCore
import SwiftUI

/// The Floating schematic (#828).
///
/// Floating drew **nothing** — `LayoutSchematicView` answered it
/// with an `EmptyView`, on the argument that a mode with no tiling
/// geometry has no picture. That argument is `MonocleSchematic`'s
/// too, and Monocle answers it by drawing its *model* instead of a
/// layout. Floating has one as well, and it is the one fact a user
/// needs: the windows stay where they were put, overlapping, and
/// the shortcuts still work. Drawn nowhere, the mode read as a
/// broken tile in the tour's strip and as a blank in Settings'
/// own "Choose a layout" row (owner, on device, 2026-08-12).
///
/// **It takes no settings, and that is the honest part.** Nothing
/// here derives from `TilingSettings`, because Floating has no
/// knob to derive from — the count is the only input, and it moves
/// the number of loose windows and nothing else.
struct FloatingSchematic: View {
    /// Windows on screen. Capped for the same reason Monocle caps
    /// its fan: past three the cards march off the canvas and say
    /// nothing the third did not.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile
    @Environment(\.schematicFocusStroke) private var focusStroke
    @Environment(\.schematicPalette) private var palette

    /// Windows actually drawn. `internal` and asserted directly
    /// (`LayoutSchematicCountTests`), never left to the source
    /// scan: a schematic that TAKES the count and draws a
    /// constant satisfies every substring a scan can look for
    /// while answering nothing — the mutation `guard-prover`
    /// shipped past that suite's first cut.
    var drawn: Int { min(max(windows, 1), 3) }

    var body: some View {
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<drawn, id: \.self) { level in
                        window(front: level == drawn - 1)
                            .frame(
                                width: geo.size.width * 0.56,
                                height: geo.size.height * 0.52
                            )
                            .offset(
                                x: geo.size.width * 0.1
                                    + CGFloat(level)
                                    * geo.size.width * 0.14,
                                y: geo.size.height * 0.1
                                    + CGFloat(level)
                                    * geo.size.height * 0.14
                            )
                    }
                }
            }
            .padding(6)
            .animation(LayoutSchematic.damping, value: windows)
        }
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

    /// Overlapping, not tiled: each window sits offset from the
    /// one behind it, and the frontmost carries the focus stroke
    /// the rest of the family uses — a floating window can be
    /// focused like any other, and drawing it otherwise would say
    /// the mode is outside the app's own focus model.
    private func window(front: Bool) -> some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(fill(front: front))
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    edge(front: front),
                    lineWidth: front ? 1.5 : 1
                )
            )
    }

    /// The caption carries what the frame cannot: that nothing
    /// moves a window here except the user, and that the keys
    /// still work — which is the question a user actually has
    /// about a space the tiler leaves alone.
    private var caption: String {
        L(
            "layout.schematic.floating.caption",
            "Windows stay where you put them, and overlap. Your "
                + "shortcuts still work."
        )
    }

    private var axLabel: String {
        L(
            "layout.schematic.floating.ax",
            "Floating preview: windows overlap where the user "
                + "left them."
        )
    }
}
