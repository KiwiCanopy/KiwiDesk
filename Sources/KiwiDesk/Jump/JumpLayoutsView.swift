import KiwiDeskCore
import SwiftUI

/// The key panel's Layouts scope (#2229): a caption naming the
/// Space, one row of every layout drawn by the Settings
/// schematics, then Layout Defaults… and Keep. The buttons are
/// reached by their chords, never Tab, which switches scope.
struct JumpLayoutsView: View {
    let list: LayoutPickList
    let settings: TilingSettings
    let commandHeld: Bool
    let onApply: (LayoutMode) -> Void
    let onKeep: () -> Void
    let onLayoutDefaults: (LayoutMode) -> Void
    /// The pointer moved over a tile.
    let onHover: (LayoutMode) -> Void

    static let tileWidth: CGFloat = 80
    static let tileSpacing: CGFloat = 6
    /// The Settings tile's schematic, scaled into a panel tile.
    static let schematicScale: CGFloat = 0.52

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption
            tiles
            buttons
        }
    }

    private var caption: some View {
        Text(
            list.selection == nil && !list.query.isEmpty
                ? LayoutPickText.noMatch(list.query)
                : LayoutPickText.caption(list.state)
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(height: 24, alignment: .bottom)
        .padding(.horizontal, KeyPanelStyle.selectionInset + 10)
    }

    private var tiles: some View {
        HStack(spacing: Self.tileSpacing) {
            ForEach(Array(list.modes.enumerated()), id: \.offset) {
                index,
                mode in
                JumpLayoutTile(
                    mode: mode,
                    number: index + 1,
                    settings: settings,
                    isSelected: index == list.selection,
                    isCurrent: mode == list.state.live,
                    isDimmed: list.isDimmed(index),
                    showsNumber: commandHeld,
                    onActivate: { onApply(mode) },
                    onHover: { onHover(mode) }
                )
            }
        }
        .frame(maxWidth: .infinity)
        // The chord line under each tile stands in for the bottom
        // padding.
        .padding(.top, 8)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            KeyPanelChordButton(
                title: LayoutPickText.layoutDefaults,
                chord: "⌘,"
            ) {
                onLayoutDefaults(list.selected ?? list.state.live)
            }
            Spacer(minLength: 0)
            if let profile = list.state.profile {
                KeyPanelChordButton(
                    title: LayoutPickText.keep(profile),
                    chord: "⌘S",
                    hint: list.state.keepArmed
                        ? nil : LayoutPickText.keepSaved
                ) { onKeep() }
                .disabled(!list.state.keepArmed)
            }
        }
        .padding(.horizontal, KeyPanelStyle.selectionInset + 10)
        .padding(.bottom, 10)
    }
}

/// One layout tile: its schematic and its name, the current one
/// marked with a ✓ glyph rather than a second green.
struct JumpLayoutTile: View {
    let mode: LayoutMode
    let number: Int
    let settings: TilingSettings
    let isSelected: Bool
    let isCurrent: Bool
    let isDimmed: Bool
    let showsNumber: Bool
    let onActivate: () -> Void
    let onHover: () -> Void
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: onActivate) { content }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel(
                LayoutPickText.spoken(mode, current: isCurrent)
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            // Spoken whether or not ⌘ is held: a VoiceOver user
            // explores without holding it.
            .accessibilityHint(LayoutPickText.chordHint("⌘\(number)"))
            .onContinuousHover { phase in
                if case .active = phase { onHover() }
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
        .frame(width: JumpLayoutsView.tileWidth)
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
                    ? AnyShapeStyle(SettingsTheme.accentInk)
                    : AnyShapeStyle(.primary)
            )
        }
        .padding(.vertical, 7)
        .frame(width: JumpLayoutsView.tileWidth)
        .background(selection)
    }

    private var schematic: some View {
        let scale = JumpLayoutsView.schematicScale
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
            accent: SettingsTheme.accentInk,
            ink: SettingsTheme.accentInk,
            base: SettingsTheme.accent
        )
    }

    @ViewBuilder private var selection: some View {
        if isSelected {
            RoundedRectangle(
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(SettingsTheme.accent)
        }
    }

    /// The quick-apply chord on its own line under the tile, off
    /// the schematic and the fill and never shortening the name;
    /// its height is held while ⌘ is up, so the panel never
    /// resizes on a press. On the panel ground on every tile.
    private var numberMark: some View {
        Text(verbatim: "⌘\(number)")
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
