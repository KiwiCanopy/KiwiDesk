import KiwiDeskCore
import SwiftUI

/// Visual grammar for layout schematic previews (#123, #125).
enum LayoutSchematic {
    static let canvasWidth: CGFloat = 140
    static let canvasHeight: CGFloat = 96
    static let corner: CGFloat = 3
    static let inset: CGFloat = 6
    static let fill = SettingsTheme.accent.opacity(0.25)
    static let stroke = SettingsTheme.accent.opacity(0.6)

    /// Shared animation timing for live slider updates (#1069).
    static let damping = Animation.easeOut(duration: 0.12)

    /// Default window count and range for preview slider.
    static let defaultWindowCount = 5
    static let windowCountRange = 2...12

    /// Overlap cascade offset scaled for schematic canvas (#712).
    static let cascadeOffset: CGFloat = 9
}

/// Rendering scale for layout schematics
/// (`LayoutSchematicScaleTests`, #678, #753).
enum SchematicScale: Hashable, CaseIterable {
    case tile
    case panel

    /// Width constraint (fixed for thumbnail tile, flexible for detail panel).
    var width: CGFloat? {
        self == .tile ? 132 : nil
    }

    var height: CGFloat {
        self == .tile ? 84 : 240
    }

    var showsCaption: Bool { self == .panel }
}

/// Geometry and ratio helpers for schematic layout.
enum SchematicMath {
    /// Ratio formatted as integer percentage.
    static func pct(_ ratio: Double) -> Int {
        Int((ratio * 100).rounded())
    }

    /// Maps point size to canvas width fraction.
    static func slotFraction(points: CGFloat) -> CGFloat {
        let t = (points - 100) / (1200 - 100)
        return 0.15 + 0.45 * min(max(t, 0), 1)
    }
}

/// Standard schematic window tile.
struct SchematicTile: View {
    var active = false
    @Environment(\.schematicPalette) private var palette
    @Environment(\.schematicFocusStroke) private var focusStroke

    var body: some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(palette?.fill ?? LayoutSchematic.fill)
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    active
                        ? focusStroke ?? palette?.stroke
                            ?? LayoutSchematic.stroke
                        : palette?.stroke
                            ?? LayoutSchematic.stroke,
                    lineWidth: active ? 2 : 1
                )
            )
    }
}

/// Overflow indicator chip displaying count of hidden windows.
struct SchematicMoreChip: View {
    let hidden: Int
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        Text("+\(hidden)")
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(
                palette?.ink ?? SettingsTheme.ink2
            )
            .padding(.horizontal, 3)
            .background(
                Capsule().fill(
                    palette?.base ?? SettingsTheme.card
                )
            )
    }
}

/// Empty cell placeholder for fixed grid layouts.
struct SchematicGap: View {
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .strokeBorder(
                palette?.gapStroke
                    ?? SettingsTheme.ink2.opacity(0.4),
                style: StrokeStyle(lineWidth: 1, dash: [3, 2])
            )
    }
}

/// Incoming window placement indicator with plus badge.
struct SchematicNewWindow: View {
    var badgeAlignment: Alignment = .bottomTrailing
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        ZStack(alignment: badgeAlignment) {
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .fill(
                    palette?.newFill
                        ?? SettingsTheme.accent.opacity(0.45)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: LayoutSchematic.corner
                    )
                    .strokeBorder(
                        palette?.stroke ?? LayoutSchematic.stroke,
                        lineWidth: 1
                    )
                )
            Image(systemName: "plus")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(
                    palette?.ink ?? SettingsTheme.accentInk
                )
                .padding(2)
        }
    }
}

/// Opaque cascading stack tile avoiding opacity compounding (#406, #712).
struct SchematicPileTile: View {
    var active = false
    var isNew = false
    @Environment(\.schematicPalette) private var palette
    @Environment(\.schematicFocusStroke) private var focusStroke

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .fill(
                    palette?.base ?? SettingsTheme.card
                )
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .fill(
                    isNew
                        ? palette?.newFill
                            ?? SettingsTheme.accent.opacity(0.45)
                        : palette?.fill ?? LayoutSchematic.fill
                )
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .strokeBorder(
                    active
                        ? focusStroke ?? palette?.stroke
                            ?? LayoutSchematic.stroke
                        : palette?.stroke
                            ?? LayoutSchematic.stroke,
                    lineWidth: active ? 2 : 1
                )
            if isNew {
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(
                        palette?.ink ?? SettingsTheme.accentInk
                    )
                    .padding(2)
            }
        }
    }
}

/// Off-monitor ghost window representation for scrolling layouts.
struct SchematicGhostOverflow: View {
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(
                palette?.ghostFill
                    ?? SettingsTheme.ink2.opacity(0.15)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    palette?.ghostStroke
                        ?? SettingsTheme.ink2.opacity(0.5),
                    lineWidth: 1
                )
            )
    }
}
