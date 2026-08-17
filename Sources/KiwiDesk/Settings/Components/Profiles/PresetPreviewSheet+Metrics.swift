import KiwiDeskCore
import SwiftUI

/// The preview sheet's ARITHMETIC (#859) — split from the drawing
/// when the doc comments the review round asked for pushed that
/// file past the 350-line ceiling.
///
/// It is a coherent unit rather than an arbitrary cut: every
/// constant here is read by `width(forColumns:)` or by the height
/// bounds, and `PresetPreviewSheetTests` asserts the lot at column
/// counts the sheet does not ship. The drawing keeps `tileColumns`,
/// which is where these are SPENT — so the needles pinning that the
/// grid states its columns rather than adapting to them still sit
/// on the file that draws.
extension PresetPreviewSheet {
    /// `.tile`'s fixed width, so the grid's column derives from
    /// the schematic it mounts rather than restating a number.
    ///
    /// The `132` is unreachable: `SchematicScale.width` answers
    /// non-nil for `.tile` by construction and nil only for
    /// `.panel`, which this sheet does not mount.
    /// `PresetPreviewSheetTests` asserts the two are equal, so the
    /// fallback cannot start standing in for a moved constant.
    static let tileWidth = SchematicScale.tile.width ?? 132
    static let gutter: CGFloat = 12
    static let pad: CGFloat = 12
    /// Room for a LEGACY scroll bar, which System Settings ▸
    /// Appearance ▸ "Show scroll bars: Always" turns on and which
    /// then insets a `ScrollView`'s content instead of overlaying
    /// it.
    ///
    /// Reserved rather than assumed away. The first cut spent the
    /// whole content box on tiles, so with `.adaptive` columns a
    /// legacy scroller re-wrapped four to three, and with `.fixed`
    /// ones it CLIPPED the fourth — the same cross-desk difference
    /// by another road (re-review, 2026-08-17). Both roads close by
    /// there being width to lose.
    static let scroller: CGFloat = 16

    /// The width that fits exactly `columns` tiles, plus the
    /// padding and the scroller allowance.
    ///
    /// The sheet's width is DERIVED from this rather than picked:
    /// the grid's job is comparison, and a sheet whose column
    /// count changes as the window resizes makes two presets look
    /// different for a reason that is not about them.
    static func width(forColumns columns: Int) -> CGFloat {
        CGFloat(columns) * tileWidth
            + CGFloat(max(columns - 1, 0)) * gutter
            + 2 * pad
            + scroller
    }

    /// Four, which is what the arithmetic allows at the narrowest
    /// window this app has. `SettingsWidthClass.minimum` is 720,
    /// and five columns need 732 — so five would be a width the
    /// sheet could not always have, and the column count would
    /// drop on a narrow desk. Four fits everywhere, and every
    /// shipped preset puts at most four Spaces on one screen, so
    /// at four columns each screen group is exactly one row.
    static let columns = 4

    /// The sheet's height bounds.
    ///
    /// **`minHeight` is a RELATION, not a taste**: it has to stay
    /// under the shell's own minimum content height or the sheet
    /// cannot be shown whole in the narrowest window the app
    /// allows. `PresetPreviewSheetTests` asserts it against
    /// `SettingsWidthClass.minimumHeight` rather than against 400.
    ///
    /// The ideal is the tall shipped case — one row per screen plus
    /// header and footer — so no catalog preset scrolls on an
    /// ordinary window. Past the max the sheet stops growing and
    /// the `ScrollView` takes over, which is also what happens on a
    /// window shorter than the ideal: macOS clamps a sheet to its
    /// parent, so the `ScrollView` is not optional.
    ///
    /// An earlier comment here claimed the max "stops it short of
    /// filling the window". That was false at both of the repo's
    /// own pinned heights — the shell floor is 540 and the window
    /// OPENS at 620 (code review, 2026-08-17). The bound is a
    /// growth stop, not a promise about the window.
    static let minHeight: CGFloat = 400
    static let idealHeight: CGFloat = 600
    static let maxHeight: CGFloat = 780
}
