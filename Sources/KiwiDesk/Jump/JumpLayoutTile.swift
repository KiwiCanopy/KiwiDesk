import KiwiDeskCore
import SwiftUI

/// One tile on the View side's Layout line (#2229, #2309): its
/// schematic and its name, the current one marked with a ✓ glyph
/// rather than a second green.
struct JumpLayoutTile: View {
    let mode: LayoutMode
    /// Its ⌘ number among the line's matches; nil past nine.
    let number: Int?
    let settings: TilingSettings
    let isSelected: Bool
    /// The pointer lifts this tile, grey (#2365).
    let isLifted: Bool
    let isCurrent: Bool
    let isDimmed: Bool
    /// ⌘ is held on this line and the tile has a number.
    let showsNumber: Bool

    static let width: CGFloat = 80
    static let spacing: CGFloat = 6
    /// The Settings tile's schematic, scaled into a panel tile.
    static let schematicScale: CGFloat = 0.52
    let onActivate: () -> Void
    let onHover: () -> Void
    let onHoverEnd: () -> Void
    @Environment(\.kiwiHubPaint) private var paint
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: onActivate) {
            content.kiwiHubRowInk(
                paint,
                selected: isSelected,
                lifted: isLifted
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(
            LayoutPickText.spoken(mode, current: isCurrent)
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // Spoken whether or not ⌘ is held: a VoiceOver user
        // explores without holding it.
        .accessibilityHint(chordHint)
        .onContinuousHover { phase in
            if case .active = phase { onHover() } else { onHoverEnd() }
        }
    }

    /// The tile proper on its selection fill, then the chord line
    /// under it, outside the fill: the fill keeps one shape with
    /// ⌘ up or down.
    private var content: some View {
        VStack(spacing: 2) {
            tile
            numberMark
        }
        .frame(width: Self.width)
        .opacity(isDimmed ? 0.35 : 1)
        .contentShape(Rectangle())
    }

    private var tile: some View {
        VStack(spacing: 5) {
            schematic
            HStack(spacing: 2) {
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(mode.displayName).lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(
                isSelected
                    ? AnyShapeStyle(paint.selectionInk)
                    : isLifted && paint.hoverInk != nil
                        ? AnyShapeStyle(paint.hoverInk ?? .primary)
                        : AnyShapeStyle(.primary)
            )
        }
        .padding(.vertical, 7)
        .frame(width: Self.width)
        .background(selection)
    }

    private var schematic: some View {
        let scale = Self.schematicScale
        return LayoutSchematicView(
            mode: mode,
            settings: settings,
            windows: LayoutSchematic.defaultWindowCount,
            scale: .tile
        )
        .frame(
            width: SchematicScale.tile.width,
            height: SchematicScale.tile.height
        )
        .scaleEffect(scale)
        .frame(
            width: (SchematicScale.tile.width ?? 0) * scale,
            height: SchematicScale.tile.height * scale
        )
        .environment(\.schematicPalette, isSelected ? onFill : nil)
        .accessibilityHidden(true)
    }

    /// The schematic's inks on the accent fill.
    private var onFill: SchematicPalette {
        SchematicPalette(
            accent: paint.selectionInk,
            ink: paint.selectionInk,
            base: paint.selection
        )
    }

    @ViewBuilder private var selection: some View {
        if isSelected {
            RoundedRectangle(
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(paint.selection)
        } else if isLifted {
            RoundedRectangle(
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(paint.rowHover)
        }
    }

    /// The tile's ⌘ number, spoken; none for a tile the query
    /// dims.
    private var chordHint: String {
        number.map { LayoutPickText.chordHint("⌘\($0)") } ?? ""
    }

    /// The quick-apply chord on its own line under the tile, off
    /// the schematic and the fill and never shortening the name;
    /// its height is held while ⌘ is up, so the panel never
    /// resizes on a press. On the panel ground on every tile.
    private var numberMark: some View {
        Text(verbatim: number.map { "⌘\($0)" } ?? "")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .opacity(showsNumber ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.15),
                value: showsNumber
            )
            .accessibilityHidden(true)
    }
}
