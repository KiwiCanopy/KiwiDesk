import KiwiDeskCore
import SwiftUI

/// An editable space name. Commits the rename on Return or when
/// focus leaves; reverts to the current name if the new one is
/// empty or already taken, so a bad edit never renames. The
/// field reports its draft's `SpaceNameNotice` through `onNotice`
/// for the row to draw, outlines itself in `danger` while the
/// name is refused, and speaks a refusal once when the revert
/// lands (#1623).
struct SpaceNameField: View {
    let space: SpaceID
    let isAvailable: (SpaceID) -> Bool
    let onRename: (SpaceID) -> Void
    let onNotice: (SpaceNameNotice?) -> Void

    @State private var draft: String
    @State private var announcement: DispatchWorkItem?
    @FocusState private var focused: Bool

    init(
        space: SpaceID,
        isAvailable: @escaping (SpaceID) -> Bool,
        onRename: @escaping (SpaceID) -> Void,
        onNotice: @escaping (SpaceNameNotice?) -> Void
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
            .overlay {
                if notice?.isRefusal == true {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            SettingsTheme.danger,
                            lineWidth: 1.5
                        )
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 180, alignment: .leading)
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .onChange(of: notice) { _, notice in onNotice(notice) }
            // A row removed mid-edit runs no `onChange`: retire
            // its caption here, or a later Space of the same id
            // inherits it.
            .onDisappear {
                onNotice(nil)
                announcement?.cancel()
            }
    }

    /// Derived per render, so it clears as the draft changes.
    private var notice: SpaceNameNotice? {
        focused ? notice(for: draft) : nil
    }

    private func notice(for draft: String) -> SpaceNameNotice? {
        SpaceNameNotice.of(
            draft: draft,
            space: space,
            isAvailable: isAvailable
        )
    }

    private func commit() {
        let target = SpaceID(draft.trimmed)
        guard target != space else {
            draft = space.raw
            return
        }
        if let refusal = notice(for: draft), refusal.isRefusal {
            draft = space.raw
            announce(refusal.sentence)
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
