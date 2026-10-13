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
        .padding(.vertical, 8)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            chordButton(LayoutPickText.layoutDefaults, chord: "⌘,") {
                onLayoutDefaults(list.selected ?? list.state.live)
            }
            Spacer(minLength: 0)
            if let profile = list.state.profile {
                chordButton(
                    LayoutPickText.keep(profile),
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

    /// A button drawing its chord the way a menu item does; the
    /// chord is its hint, never its name.
    private func chordButton(
        _ title: String,
        chord: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).lineLimit(1)
                Text(verbatim: chord)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .settingsActionButton()
        .controlSize(.small)
        // The field keeps the keys; the chord reaches the button.
        .focusable(false)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? LayoutPickText.chordHint(chord))
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

    var body: some View {
        Button(action: onActivate) { content }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel(
                LayoutPickText.spoken(mode, current: isCurrent)
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .onContinuousHover { phase in
                if case .active = phase { onHover() }
            }
    }

    private var content: some View {
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
        .overlay(alignment: .topTrailing) { numberMark }
        .opacity(isDimmed ? 0.35 : 1)
        .contentShape(Rectangle())
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

    @ViewBuilder private var numberMark: some View {
        if showsNumber {
            Text(verbatim: "⌘\(number)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(
                    isSelected
                        ? AnyShapeStyle(SettingsTheme.accentInkSecondary)
                        : AnyShapeStyle(.secondary)
                )
                .padding(4)
                .accessibilityHidden(true)
        }
    }
}
