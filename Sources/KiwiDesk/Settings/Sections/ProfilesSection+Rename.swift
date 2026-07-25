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
        .popover(
            isPresented: Binding(
                get: { renaming == name },
                set: { if !$0 { renaming = nil } }
            )
        ) {
            HStack {
                TextField(
                    L("footer.profile_name", "Profile name"),
                    text: $renameDraft
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
                .onSubmit { commitRename(of: name) }
                Button(L("profiles.rename", "Rename")) {
                    commitRename(of: name)
                }
                .disabled(!canRename(name))
            }
            .padding(10)
        }
    }

    /// Mirrors the core's case-insensitive collision check
    /// (APFS: "a" → "B" collides with "b"), still allowing
    /// the case-only self-rename ("work" → "Work"). One
    /// optimistic mirror is the limit (review 2026-07): a
    /// second GUI consumer of this rule gets a read-only
    /// availability query on the KiwiCore facade instead of
    /// a copy — core stays the only authority either way.
    func canRename(_ old: String) -> Bool {
        let new = renameDraft.trimmed
        guard !new.isEmpty, new != old else { return false }
        return !model.profiles.contains {
            $0.caseInsensitiveCompare(new) == .orderedSame
                && $0.caseInsensitiveCompare(old)
                    != .orderedSame
        }
    }

    func beginRename(_ name: String) {
        renameDraft = name
        renaming = name
    }

    func commitRename(of old: String) {
        guard canRename(old) else { return }
        // Rename reloads too (the core chases the file, the
        // adopted name, and the binding lines), so it discards
        // staged edits like Load and Delete (#515). The row
        // leaves edit mode either way — a cancelled discard
        // must not strand it mid-rename.
        let draft = renameDraft
        renaming = nil
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
