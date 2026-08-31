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
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Bordered mini-screen frame with standard inset and corner radius
    /// (`LayoutSchematic.inset`, `docs/ui-patterns.md`, #753).
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
