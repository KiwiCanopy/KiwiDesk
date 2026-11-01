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
    /// Caption room reserved, so a line of tiles ends level; nil
    /// reserves two lines under a caption and none without one.
    var captionLines: Int?
    /// Hover help and VoiceOver hint where the caption is not drawn.
    var help: String?
    /// Told when the pointer enters and leaves, for a surface that
    /// previews the look under it (Simple, #2737 ruling 9).
    var hover: ((Bool) -> Void)?
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
                // Simple's line draws the name alone (#2737 ruling
                // 3), so it reserves no caption room.
                captionLines: captionLines
                    ?? (caption == nil ? 0 : Self.captionRoom)
            ) {
                LookPlate(settings: preview, spaceLabels: spaceLabels)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover?($0) }
        .accessibilityAddTraits(applied ? [.isSelected] : [])
        .accessibilityHint(help ?? "")
        .help(other ? restoreColorsHelp : (help ?? ""))
    }

    /// The lines a captioned tile reserves: a description or a
    /// byline, so a line of them ends level.
    static let captionRoom = 2

    /// An imported look's caption, its author (#1740).
    @MainActor static func byline(_ author: String) -> String {
        L("looks.byline", "by %1$@", author)
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

    private var preview: TilingSettings {
        look.painted(over: model.config.settings)
    }

    private var spaceLabels: [SpaceGlyph] {
        BarsPanelPreview.spaceLabels(of: model.config)
    }
}
