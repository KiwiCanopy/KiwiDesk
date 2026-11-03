import KiwiDeskCore
import SwiftUI

/// Name edit popovers for saving and renaming a look (#1684,
/// `NameEditPopover`).
extension LooksShelf {
    @MainActor static var namePlaceholder: String {
        L("looks.name_placeholder", "Look name")
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

    func renamePopover(_ request: NameEditRequest) -> some View {
        Self.renamePopover(request, model: model) { name, old in
            renameLook(name, from: old)
        }
    }

    /// The one rename popover for a user look, Advanced's and
    /// Simple's (#2943); `rename` gets the new name, then the old.
    static func renamePopover(
        _ request: NameEditRequest,
        model: SettingsModel,
        rename: @escaping (String, String) -> Void
    ) -> some View {
        let old = request.subject ?? request.seed
        return NameEditPopover(
            seed: request.seed,
            placeholder: namePlaceholder,
            width: 160,
            confirmLabel: { _ in L("looks.rename_confirm", "Rename") },
            isValid: { model.canRenameUserLook($0, from: old) }
        ) { name in
            rename(name, old)
        }
    }
}
