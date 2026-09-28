import KiwiDeskCore
import SwiftUI

/// Floating layout preview schematic: windows scattered where
/// they were left, overlapping (#828, #1750).
struct FloatingSchematic: View {
    /// Window count clamped to schematic rendering bounds.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile
    /// Tour story phase (`SchematicMotion.drag`, #1750).
    var drag: Double = 1
    @Environment(\.schematicFocusStroke) private var focusStroke
    @Environment(\.schematicPalette) private var palette

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.schematicRestage) private var restage

    /// Restage animation damping gated on Reduce Motion
    /// (`\.schematicRestage`, #1069).
    private var damping: Animation? {
        reduceMotion ? nil : restage
    }

    /// Windows actually drawn. `internal` and asserted directly
    /// (`LayoutSchematicCountTests`), never left to the source
    /// scan: a schematic that TAKES the count and draws a constant
    /// satisfies every substring a scan can look for — the
    /// mutation `guard-prover` shipped past that suite's first
    /// cut.
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
                        placed(level, in: geo.size)
                    }
                    pointer(in: geo.size)
                }
            }
            .padding(6)
            .animation(damping, value: windows)
        }
    }

    /// Where each window rests, as fractions of the canvas, back
    /// to front: scattered rather than cascaded, since a floating
    /// window sits wherever it was left. A count below three
    /// keeps the front ones.
    static let scatter: [CGRect] = [
        CGRect(x: 0.04, y: 0.06, width: 0.44, height: 0.42),
        CGRect(x: 0.54, y: 0.14, width: 0.42, height: 0.46),
        CGRect(x: 0.28, y: 0.52, width: 0.46, height: 0.42),
    ]

    /// Where the front window is picked up before its drag.
    static let pickUp = CGPoint(x: 0.04, y: 0.54)

    /// Window `level`'s frame on a canvas of `size`; the front
    /// one travels from `pickUp` as `drag` runs to 1.
    func frame(_ level: Int, in size: CGSize) -> CGRect {
        let slot = Self.scatter[Self.scatter.count - drawn + level]
        var origin = slot.origin
        if level == drawn - 1 {
            let t = CGFloat(drag)
            origin.x = Self.pickUp.x + (slot.minX - Self.pickUp.x) * t
            origin.y = Self.pickUp.y + (slot.minY - Self.pickUp.y) * t
        }
        return CGRect(
            x: origin.x * size.width,
            y: origin.y * size.height,
            width: slot.width * size.width,
            height: slot.height * size.height
        )
    }

    private func placed(_ level: Int, in size: CGSize) -> some View {
        let rect = frame(level, in: size)
        return window(front: level == drawn - 1)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// The hand dragging the front window: shown at the pick-up,
    /// fading as the drag lands, gone at rest.
    private func pointer(in size: CGSize) -> some View {
        let rect = frame(drawn - 1, in: size)
        return Image(systemName: "cursorarrow")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(palette?.ink ?? SettingsTheme.ink)
            .offset(x: rect.midX, y: rect.midY - 2)
            .opacity(drag < 1 ? 1 : 0)
            .accessibilityHidden(true)
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
