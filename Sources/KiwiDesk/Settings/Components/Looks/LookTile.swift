import KiwiDeskCore
import SwiftUI

/// One look's tile, drawn by the Looks shelf and by Simple's Look
/// line (#2737): the picture is what a click gives — the look, its
/// colors included — over the draft; the mark is Core's one reading
/// (`ShelfLook.match`), and a look whose shape is live in other
/// colors keeps it, saying so (#1752).
struct LookTile: View {
    @ObservedObject var model: SettingsModel
    let look: ShelfLook
    /// Drawn under the name; nil draws the name alone.
    let caption: String?
    let apply: () -> Void

    var body: some View {
        let match = look.match(model.config.settings)
        let applied = match != .none
        let other = match == .otherColors
        Button(action: apply) {
            PaletteTile(
                name: look.name,
                caption: caption,
                isApplied: applied,
                note: other ? otherColorsNote : nil,
                appliedSpoken: other ? otherColorsSpoken : nil,
                captionLines: 2
            ) {
                LookPlate(settings: preview, spaceLabels: spaceLabels)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(applied ? [.isSelected] : [])
        .help(other ? restoreColorsHelp : "")
    }

    private var otherColorsNote: String {
        L("looks.other_colors", "Other colors")
    }

    private var otherColorsSpoken: String {
        L("looks.applied_other_colors", "Applied, with other colors")
    }

    private var restoreColorsHelp: String {
        L(
            "looks.restore_colors.help",
            "Click to bring back this look's own colors."
        )
    }

    /// The draft with `look` painted on, its colors included.
    private var preview: TilingSettings {
        var settings = model.config.settings
        look.apply(to: &settings)
        return settings
    }

    private var spaceLabels: [SpaceGlyph] {
        BarsPanelPreview.spaceLabels(of: model.config)
    }
}
