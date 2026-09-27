import KiwiDeskCore
import SwiftUI

/// Name edit popovers for palette saving and renaming (#843,
/// `NameEditPopover`).
extension PaletteShelf {
    @MainActor static var namePlaceholder: String {
        L("palettes.name_placeholder", "Palette name")
    }

    func savePopover(_ request: NameEditRequest) -> some View {
        NameEditPopover(
            seed: request.seed,
            placeholder: Self.namePlaceholder,
            confirmLabel: saveLabel,
            isValid: canSave,
            notice: saveNotice
        ) { name in
            saveCurrent(name)
        }
    }

    func renamePopover(
        _ request: NameEditRequest
    ) -> some View {
        let old = request.subject ?? request.seed
        return NameEditPopover(
            seed: request.seed,
            placeholder: Self.namePlaceholder,
            width: 160,
            confirmLabel: { _ in
                L("palettes.rename_confirm", "Rename")
            },
            isValid: { canRename($0, from: old) }
        ) { name in
            renamePalette(name, from: old)
        }
    }
}
