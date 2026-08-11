import KiwiDeskCore
import SwiftUI

/// The live preview beside the per-space override editor (#678
/// 8b): the space's active layout drawn with ITS overrides
/// applied, so a ratio or count the user overrides shows here at
/// once. It feeds the same `LayoutSchematicView` the Layout
/// Defaults preview uses — via `TilingSettings.resolved(for:
/// activeMode:)`, the engine's own resolver — so the preview asks
/// the engine rather than re-deriving placement beside the drawing
/// (gui.md). It sits in the editor's trailing column for now (owner
/// call 2026-08-04; this panel is being reworked in a later step).
/// Floating has no schematic, so the editor draws no preview for it.
///
/// The window count is view state, the same question the Layout
/// Defaults preview poses: overflow, track limits and dynamic-grid
/// balance are invisible at one fixed count, so the reader drives
/// it — and it never persists or reaches the config.
struct SpaceOverridePreview: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    let mode: LayoutMode
    @State private var windows = LayoutSchematic.defaultWindowCount

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("space_override.preview", "Preview"))
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            LayoutSchematicView(
                mode: mode,
                settings: model.config.settings.resolved(
                    for: space,
                    activeMode: mode
                ),
                windows: windows,
                scale: .panel
            )
            countRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.sunken)
        )
    }

    private var countRange: ClosedRange<Double> {
        let band = LayoutSchematic.windowCountRange
        return Double(band.lowerBound)...Double(band.upperBound)
    }

    /// Compact — no wide label column, since the preview column is
    /// narrower than a settings row: the caption above names the
    /// layout, so this is slider + count readout only.
    private var countRow: some View {
        HStack(spacing: 8) {
            // Both texts are drawn for the eye and hidden from
            // VoiceOver, which hears them from the slider itself
            // — see the naming below. Spoken as siblings they
            // are three elements for one value, and the middle
            // one is the only one that can be adjusted.
            Text(L("layout_defaults.preview_windows", "Window count"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            SettingsSlider(
                value: Binding(
                    get: { Double(windows) },
                    set: { windows = Int($0.rounded()) }
                ),
                range: countRange,
                step: 1
            )
            // A sibling `Text` names nothing to VoiceOver, so
            // this slider announced a bare percentage — the same
            // defect the Layout Defaults panel carried, in its
            // second copy, which the first fix left behind (code
            // review, 2026-08-11).
            .accessibilityLabel(
                L("layout_defaults.preview_windows", "Window count")
            )
            .accessibilityValue("\(windows)")
            Text("\(windows)")
                .frame(width: 24, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.caption.monospacedDigit())
                .accessibilityHidden(true)
        }
    }
}
