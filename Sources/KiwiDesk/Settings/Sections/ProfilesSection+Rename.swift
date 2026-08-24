import KiwiDeskCore
import SwiftUI

/// The saved-profile rename affordance, split out of
/// `ProfilesSection` for the file ceiling. State
/// (`renaming` / `renameDraft`) stays on the view — extensions
/// cannot hold `@State` — so only the button and its three
/// helpers live here.
extension ProfilesSection {
    /// Rename is a pencil right beside the profile name (in
    /// front of the badges), opening a popover. The rename is
    /// immediate (file + native-Space bindings follow), like
    /// Delete and make default. Unlike the other icon-only
    /// borderless buttons, the pencil stays persistently visible
    /// (a soft always-on background circle, matching
    /// `hoverHighlight`'s hover value at rest) rather than
    /// hover-only — it is the primary discovery path for
    /// renaming, so it must not require finding it first.
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
            // Presented by ITEM so the seed reaches the builder
            // instead of being read back out of `@State` written
            // one tick earlier (#843). Latent here rather than
            // live — this gate refuses the unchanged name, so a
            // stale empty draft and a fresh seed both disable
            // the button — but it is the same shape, and a
            // relaxed gate would make it visible.
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

    /// The request for THIS row, so only the renamed row
    /// presents.
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

    /// Mirrors the core's case-insensitive collision check
    /// (APFS: "a" → "B" collides with "b"), still allowing
    /// the case-only self-rename ("work" → "Work"). One
    /// optimistic mirror is the limit (review 2026-07): a
    /// second GUI consumer of this rule gets a read-only
    /// availability query on the KiwiCore facade instead of
    /// a copy — core stays the only authority either way.
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
        // Rename reloads too (the core chases the file, the
        // adopted name, and the binding lines), so it discards
        // staged edits like Load and Delete (#515). The row
        // leaves edit mode either way — a cancelled discard
        // must not strand it mid-rename.
        let draft = typed
        renameRequest = nil
        // One turn later, deliberately. `renaming = nil`
        // dismisses an NSPopover; requesting the confirm sheet
        // in the same update can drop it while that dismissal
        // animates, and a dropped sheet makes Rename a dead
        // click that silently keeps the edits. Both reviewers
        // flagged the combination independently. Ordering only —
        // the draft and the old name are already captured, so
        // nothing here can go stale.
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
