import SwiftUI

extension Notification.Name {
    /// Posted on main before a Save or a leave reads the draft
    /// (#2584); a focused field that commits on blur commits on it.
    static let settingsCommitField = Self("kiwidesk.settings.commitField")
}

extension View {
    /// The one way a Settings field that keeps its typing local
    /// commits it: on Return, on losing focus, and while focused on
    /// a commit request, delivered before the request returns
    /// (#2584). Whichever window is key, and the caret stays put.
    func commitsOnSave(
        _ focus: FocusState<Bool>.Binding,
        _ commit: @escaping () -> Void
    ) -> some View {
        focused(focus)
            .onSubmit(commit)
            .onChange(of: focus.wrappedValue) { _, now in
                if !now { commit() }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .settingsCommitField
                )
            ) { _ in
                if focus.wrappedValue { commit() }
            }
    }
}

extension SettingsModel {
    /// Lands a value still being typed in the draft, so what reads
    /// the draft next reads it too (#2584).
    func commitFocusedField() {
        NotificationCenter.default.post(
            name: .settingsCommitField,
            object: nil
        )
    }

    /// ⌘S: commits the field being typed in, then saves when that
    /// leaves something to save — a typed value can be the one
    /// edit, which the greyed Save button cannot hear.
    func saveFromKeyboard() {
        commitFocusedField()
        guard primarySaveEnabled else { return }
        performPrimarySave()
    }
}
