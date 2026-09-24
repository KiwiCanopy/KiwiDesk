import KiwiDeskCore
import SwiftUI

/// An editable space name. Commits the rename on Return or when
/// focus leaves; reverts to the current name if the new one is
/// empty or already taken, so a bad edit never renames. A taken
/// name is said, not only refused (#1623): the field reports the
/// caption its draft earns through `onNotice` for the row to draw,
/// and speaks it once when the revert lands.
struct SpaceNameField: View {
    let space: SpaceID
    let isAvailable: (SpaceID) -> Bool
    let onRename: (SpaceID) -> Void
    let onNotice: (String?) -> Void

    @State private var draft: String
    @State private var announcement: DispatchWorkItem?
    @FocusState private var focused: Bool

    init(
        space: SpaceID,
        isAvailable: @escaping (SpaceID) -> Bool,
        onRename: @escaping (SpaceID) -> Void,
        onNotice: @escaping (String?) -> Void
    ) {
        self.space = space
        self.isAvailable = isAvailable
        self.onRename = onRename
        self.onNotice = onNotice
        _draft = State(initialValue: space.raw)
    }

    var body: some View {
        TextField("", text: $draft)
            .textFieldStyle(.roundedBorder)
            // Accessible label for the nameless field (#812) —
            // the DIFF ROW's key, not a twin: one key cannot
            // disagree with itself across ten locales.
            .accessibilityLabel(
                L("diff.label.space_name", "Space name")
            )
            .fontWeight(.medium)
            .focused($focused)
            .frame(width: 180, alignment: .leading)
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in
                if isFocused {
                    announcement?.cancel()
                } else {
                    commit()
                }
            }
            .onChange(of: notice) { _, notice in onNotice(notice) }
    }

    /// The caption while the focused draft names another Space.
    /// Derived per render, so it clears as the draft changes.
    private var notice: String? {
        focused ? takenNotice(for: draft) : nil
    }

    private func takenNotice(for draft: String) -> String? {
        Self.takenNotice(
            draft: draft,
            space: space,
            isAvailable: isAvailable
        )
    }

    /// The refusal a draft earns: a name another Space holds.
    /// Empty and unchanged drafts revert without a sentence.
    static func takenNotice(
        draft: String,
        space: SpaceID,
        isAvailable: (SpaceID) -> Bool
    ) -> String? {
        let target = SpaceID(draft.trimmed)
        guard target != space, !target.raw.isEmpty,
            !isAvailable(target)
        else { return nil }
        return L(
            "spaces.rename.taken",
            "A Space named “%1$@” already exists.",
            target.raw
        )
    }

    private func commit() {
        let target = SpaceID(draft.trimmed)
        guard target != space else {
            draft = space.raw
            return
        }
        if let refusal = takenNotice(for: draft) {
            draft = space.raw
            announce(refusal)
            return
        }
        guard !target.raw.isEmpty else {
            draft = space.raw
            return
        }
        onRename(target)
    }

    /// Speaks a refusal once, after `SettingsFooter`'s measured
    /// delay — a post landing with the control's own
    /// announcement is dropped (#812).
    private func announce(_ sentence: String) {
        announcement?.cancel()
        let work = DispatchWorkItem {
            AccessibilityNotification.Announcement(sentence).post()
        }
        announcement = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + SettingsFooter.announceDelay,
            execute: work
        )
    }
}
