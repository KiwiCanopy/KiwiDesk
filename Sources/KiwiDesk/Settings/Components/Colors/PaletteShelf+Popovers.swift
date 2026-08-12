import KiwiDeskCore
import SwiftUI

/// The palette shelf's two popovers, both built on
/// `PaletteNamePopover` — which OWNS the name it edits (#843).
///
/// Split from `PaletteShelf.swift` when the card chrome pushed it
/// past §2.1's size band. They belong together and apart from the
/// grid: both are a text field plus a confirm button over the
/// same name rules (`canSave` / `canRename` in
/// `PaletteShelf+Actions.swift`), and neither draws a tile.
///
/// Each seeds from a value in SCOPE — a freshly computed unique
/// name, the palette's own name — never from shelf `@State`
/// written in the same tick as the presentation, which is what
/// left Save disabled over a valid name on the first open of
/// every visit.
extension PaletteShelf {
    var savePopover: some View {
        PaletteNamePopover(
            seed: nextUserName(),
            confirmLabel: saveLabel,
            isValid: canSave,
            notice: saveNotice
        ) { name in
            saveCurrent(name)
        }
    }

    func renamePopover(
        _ palette: ColorPalette
    ) -> some View {
        PaletteNamePopover(
            seed: palette.name,
            width: 160,
            confirmLabel: { _ in
                L("palettes.rename_confirm", "Rename")
            },
            isValid: { canRename($0, from: palette.name) }
        ) { name in
            renamePalette(name, from: palette.name)
        }
    }
}
