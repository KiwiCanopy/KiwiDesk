import SwiftUI

/// The bordered mini-screen a schematic draws into: a rounded
/// outline with the content clipped inside, so every frame in the
/// family reads the same and none can draw past its own edges.
/// A `nil` width means "fill the width available" — the panel
/// scale spans its pane rather than sitting at a fixed size, so
/// the live preview grows with the Settings window.
struct SchematicScreen<Content: View>: View {
    var width: CGFloat? = LayoutSchematic.canvasWidth
    var height: CGFloat = LayoutSchematic.canvasHeight
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            content
                .padding(LayoutSchematic.inset)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: width == nil ? .infinity : nil)
        .frame(width: width, height: height)
    }
}

/// A schematic: one mini-screen plus a caption, centred as a
/// self-contained tile. Size defaults to the family 140×96 but a
/// mode may grow it (BSP argues from a widescreen frame).
///
/// **One frame per layout, whatever it has to say** (#753). A
/// two-frame pair shipped here for the one fact thought
/// inexpressible in a still frame — Scrolling's `follow` pan —
/// and bought nothing: two states with the tween left to the
/// reader is not motion either, and it cost double the width, an
/// arrow drawn nowhere else and two sub-captions. The caption
/// says the fact in words for the price of a line, so a layout
/// asking for a second frame is asking for a better caption.
///
/// Centered on purpose (the `.frame(maxWidth:.infinity)` with no
/// alignment): this is a **standalone illustration** — nothing is
/// edited on it and no control column shares its row, so it reads
/// as a figure, not a row (see design-decisions "Preview
/// alignment splits on standalone-vs-paired"). A preview that
/// *does* sit beside its controls (GapsDiagram, the Drag columns)
/// is left-aligned instead.
struct SchematicCanvas<Content: View>: View {
    var width: CGFloat? = LayoutSchematic.canvasWidth
    var height: CGFloat = LayoutSchematic.canvasHeight
    let caption: String
    let axLabel: String
    /// A thumbnail suppresses the caption — the strip titles it
    /// (`SchematicScale.showsCaption`). The a11y label stays
    /// either way: a tile with no caption would otherwise read
    /// as an unlabelled image.
    var showsCaption = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 4) {
            SchematicScreen(width: width, height: height) {
                content
            }
            .accessibilityElement()
            .accessibilityLabel(axLabel)
            if showsCaption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
