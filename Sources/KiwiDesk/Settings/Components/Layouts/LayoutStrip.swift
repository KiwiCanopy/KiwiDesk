import KiwiDeskCore
import SwiftUI

/// The "Choose a layout" strip (turn 10): a row of **live
/// thumbnails**, not a tab strip of words.
///
/// This is the area's structural move. "Track" and "Scrolling"
/// and "Monocle" are words only a tiler user knows, and this is
/// the card where a beginner is most lost — a drawing of the
/// layout is the only honest label, so the strip doubles as the
/// answer to "which of these do I want?". Each tile also says
/// how many spaces use it, so a layout nothing runs is visibly
/// not worth tuning.
///
/// The tiles draw the *staged* settings, like every other
/// preview here: they are the same schematics the panel below
/// renders, at `SchematicScale.tile`.
struct LayoutStrip: View {
    @ObservedObject var model: SettingsModel
    @Binding var selection: LayoutMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsGroupHeader(chooseTitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(
                        LayoutMode.placementTabs,
                        id: \.self
                    ) { mode in
                        tile(mode)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        // The same string the header shows: a container VoiceOver
        // names one thing while the screen reads another is two
        // names for one control, and the old key's English still
        // described the tab strip this area no longer has.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chooseTitle)
    }

    private var chooseTitle: String {
        L("layout_defaults.choose", "Choose a layout")
    }

    private func tile(_ mode: LayoutMode) -> some View {
        let selected = mode == selection
        return Button {
            selection = mode
        } label: {
            VStack(spacing: 4) {
                LayoutSchematicView(
                    mode: mode,
                    settings: model.config.settings,
                    // The tiles all draw the same count, so the
                    // strip compares seven layouts rather than
                    // seven arbitrary window counts; the panel
                    // below is where the count is the question.
                    windows: LayoutSchematic.defaultWindowCount,
                    scale: .tile
                )
                Label(mode.displayName, systemImage: mode.glyph)
                    .font(.subheadline)
                    .labelStyle(.titleAndIcon)
                Text(usageText(mode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
            .background(selectionChrome(selected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            selected ? [.isButton, .isSelected] : .isButton
        )
    }

    /// The selected tile is marked by a filled, accent-bordered
    /// plate rather than by tinting the drawing: the thumbnail is
    /// the layout's own picture, and recolouring it would make
    /// "selected" and "this is what the accent colour paints"
    /// the same signal.
    private func selectionChrome(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                selected
                    ? SettingsTheme.accent.opacity(0.12)
                    : SettingsTheme.card
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        selected
                            ? SettingsTheme.accent
                            : Color.secondary.opacity(0.25),
                        lineWidth: selected ? 2 : 1
                    )
            )
    }

    /// How many spaces run this layout. A space with no recorded
    /// mode runs the default, exactly as everywhere else reads
    /// it (`?? .bsp`), so BSP's count includes the untouched
    /// spaces rather than under-reporting them.
    private func usageText(_ mode: LayoutMode) -> String {
        let count = LayoutUsage.spaces(
            on: mode,
            in: model.config
        ).count
        if count == 0 {
            return L("layout_defaults.uses.none", "No spaces")
        }
        if count == 1 {
            return L("layout_defaults.uses.one", "1 space")
        }
        return L(
            "layout_defaults.uses.many",
            "%1$d spaces",
            count
        )
    }
}
