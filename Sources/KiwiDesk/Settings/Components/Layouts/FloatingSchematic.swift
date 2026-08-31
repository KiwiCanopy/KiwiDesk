import KiwiDeskCore
import SwiftUI

/// Floating layout preview schematic showing overlapping windows (#828).
struct FloatingSchematic: View {
    /// Window count clamped to schematic rendering bounds.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile
    @Environment(\.schematicFocusStroke) private var focusStroke
    @Environment(\.schematicPalette) private var palette

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Restage animation damping gated on Reduce Motion
    /// (`LayoutSchematic.damping`, #1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    /// Windows actually drawn (`LayoutSchematicCountTests`).
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
            .animation(damping, value: windows)
        }
    }

    /// Card background fill (`SchematicCardColors`).
    private func fill(front: Bool) -> Color {
        SchematicCardColors.fill(front: front, palette: palette)
    }

    /// Card border stroke (`SchematicCardColors`).
    private func edge(front: Bool) -> Color {
        SchematicCardColors.edge(
            front: front,
            focusStroke: focusStroke,
            palette: palette
        )
    }

    /// Renders overlapping window rectangle.
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
