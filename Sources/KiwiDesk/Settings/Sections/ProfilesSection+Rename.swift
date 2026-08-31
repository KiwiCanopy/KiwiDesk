import KiwiDeskCore
import SwiftUI

/// Profile rename affordance and validation for ProfilesSection.
extension ProfilesSection {
    /// Renders rename button with name-editing popover (#843).
    func renameButton(_ name: String) -> some View {
        Button {
            beginRename(name)
        } label: {
            Image(systemName: "pencil")
                .imageScale(.medium)
        }
        .buttonStyle(.borderless)
        .frame(width: 22, height: 22)
        .iconButtonAffordance(
            L("profiles.rename.help", "Rename profile"),
            cornerRadius: 11,
            padding: 0
        )
        .popover(item: renameBinding(name)) { request in
            NameEditPopover(
                seed: request.seed,
                placeholder: L("footer.profile_name", "Profile name"),
                width: 160,
                confirmLabel: { _ in
                    L("profiles.rename", "Rename")
                },
                isValid: { canRename($0, of: name) }
            ) { draft in
                commitRename(draft, of: name)
            }
        }
    }

    /// Binding presenting popover exclusively for matching profile name.
    func renameBinding(
        _ name: String
    ) -> Binding<NameEditRequest?> {
        Binding(
            get: {
                renameRequest?.subject == name
                    ? renameRequest : nil
            },
            set: { if $0 == nil { renameRequest = nil } }
        )
    }

    /// Validates uniqueness case-insensitively while permitting
    /// case-only renames.
    func canRename(_ typed: String, of old: String) -> Bool {
        let new = typed.trimmed
        guard !new.isEmpty, new != old else { return false }
        return !model.profiles.contains {
            $0.caseInsensitiveCompare(new) == .orderedSame
                && $0.caseInsensitiveCompare(old)
                    != .orderedSame
        }
    }

    func beginRename(_ name: String) {
        renameRequest = NameEditRequest(
            seed: name,
            subject: name
        )
    }

    func commitRename(_ typed: String, of old: String) {
        guard canRename(typed, of: old) else { return }
        let draft = typed
        renameRequest = nil
        DispatchQueue.main.async {
            requestRename(from: old, draft: draft)
        }
    }

    private func requestRename(
        from old: String,
        draft: String
    ) {
        model.discardingEdits(
            message: L(
                "discard.rename_profile.message",
                "Renaming reloads the dashboard, dropping the "
                    + "edits you haven't saved."
            ),
            confirmLabel: L(
                "discard.rename_profile.confirm",
                "Discard & rename"
            )
        ) { model.renameProfile(from: old, to: draft) }
    }
}
