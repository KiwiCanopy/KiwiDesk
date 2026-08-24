import KiwiDeskCore
import SwiftUI

/// The palette shelf's two name popovers, both built on the
/// shared `NameEditPopover`, which OWNS the name it edits (#843).
///
/// Each is presented by ITEM, so the seed travels to the builder
/// instead of being read back out of shelf state written one tick
/// earlier — which is what left Save disabled over a valid name
/// on the first open of every visit.
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
