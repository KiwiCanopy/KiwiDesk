import KiwiDeskCore
import SwiftUI

/// The palette shelf's two popovers: naming a palette on save and
/// renaming one afterwards (#375).
///
/// Split from `PaletteShelf.swift` when the card chrome pushed it
/// past §2.1's size band. They belong together and apart from the
/// grid: both are a text field plus a confirm button over the
/// same name rules (`canSave` / `canRename` in
/// `PaletteShelf+Actions.swift`), and neither draws a tile.
extension PaletteShelf {
    var savePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                L("palettes.name_placeholder", "Palette name"),
                text: $saveName
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
            .onSubmit(saveCurrent)
            if store.isBuiltinName(trimmed(saveName)) {
                Text(
                    L(
                        "palettes.reserved",
                        "That name is a built-in palette — "
                            + "choose another."
                    )
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            }
            HStack {
                Spacer()
                Button(saveLabel, action: saveCurrent)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(12)
    }

    func renamePopover(
        _ palette: ColorPalette
    ) -> some View {
        HStack {
            TextField(
                L("palettes.name_placeholder", "Palette name"),
                text: $renameDraft
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 160)
            .onSubmit { renamePalette(from: palette.name) }
            Button(L("palettes.rename_confirm", "Rename")) {
                renamePalette(from: palette.name)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canRename(from: palette.name))
        }
        .padding(10)
    }
}
