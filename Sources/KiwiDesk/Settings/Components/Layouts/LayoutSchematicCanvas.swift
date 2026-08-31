import SwiftUI

/// Schematic preview canvas tile rendering mini-screen and caption (#753).
struct SchematicCanvas<Content: View>: View {
    var width: CGFloat? = LayoutSchematic.canvasWidth
    var height: CGFloat = LayoutSchematic.canvasHeight
    let caption: String
    let axLabel: String
    var showsCaption = true
    @Environment(\.schematicPalette) private var palette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 4) {
            screen
                .accessibilityElement()
                .accessibilityLabel(axLabel)
            if showsCaption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    // `axLabel` is the spoken form of this
                    // drawing; the caption read as well was the
                    // same fact twice at `.panel` (#812).
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Bordered mini-screen frame. THE CLIP DOES NOT CROP WHERE A
    /// READER ASSUMES, and this is where that is written down:
    /// content is padded by `LayoutSchematic.inset` and only then
    /// clipped at the border, so a shape left to the clip still
    /// bleeds into the inset band — a schematic that must not draw
    /// there skips the drawing instead (#753). Prose in gui.md,
    /// `docs/ui-patterns.md` and design-decisions CITES THIS SITE
    /// rather than restating the mechanism. A `nil` width means
    /// "fill the available width".
    private var screen: some View {
        ZStack {
            content
                .padding(LayoutSchematic.inset)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    palette?.frame
                        ?? SettingsTheme.ink2.opacity(0.6)
                )
        }
        .frame(maxWidth: width == nil ? .infinity : nil)
        .frame(width: width, height: height)
    }
}
