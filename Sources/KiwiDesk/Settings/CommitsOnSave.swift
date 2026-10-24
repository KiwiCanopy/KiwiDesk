import SwiftUI

extension Notification.Name {
    /// Posted on main, its object the `SettingsModel`, before a
    /// Save or a leave reads the draft (#2584); a focused field
    /// that commits on blur commits on it.
    static let settingsCommitField = Self("kiwidesk.settings.commitField")
}

extension EnvironmentValues {
    /// The model whose commit requests the fields below answer,
    /// set once at the Settings root (#2584). Nil answers every
    /// request.
    @Entry var settingsCommitScope: ObjectIdentifier?
}

extension View {
    /// The one way a Settings field that keeps its typing local
    /// commits it: on Return, on losing focus, and while focused on
    /// its window's commit request, delivered before the request
    /// returns (#2584). The caret stays put.
    func commitsOnSave(
        _ focus: FocusState<Bool>.Binding,
        _ commit: @escaping () -> Void
    ) -> some View {
        modifier(CommitsOnSave(focus: focus, commit: commit))
    }
}

private struct CommitsOnSave: ViewModifier {
    let focus: FocusState<Bool>.Binding
    let commit: () -> Void
    @Environment(\.settingsCommitScope) private var scope

    func body(content: Content) -> some View {
        content
            .focused(focus)
            .onSubmit(commit)
            .onChange(of: focus.wrappedValue) { _, now in
                if !now { commit() }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .settingsCommitField
                )
            ) { note in
                guard focus.wrappedValue, answers(note) else { return }
                commit()
            }
    }

    /// A field answers its own window's model, or any model where
    /// no Settings root scoped it.
    private func answers(_ note: Notification) -> Bool {
        guard let scope else { return true }
        return (note.object as AnyObject?).map(ObjectIdentifier.init)
            == scope
    }
}

/// ⌘S on the Settings root, mounted and enabled whatever the draft:
/// a typed value can be the one edit, and the footer draws nothing
/// while the draft is clean (#2584).
struct KeyboardSaveButton: View {
    let model: SettingsModel

    var body: some View {
        Button("") { model.saveFromKeyboard() }
            .keyboardShortcut("s")
            // Reached by its chord, never Tab.
            .focusable(false)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}

/// The models whose request already went out in the running chain
/// of calls, cleared on the run loop's next pass.
@MainActor private var committedThisTurn: Set<ObjectIdentifier> = []

extension SettingsModel {
    /// Lands a value still being typed in the draft, so what reads
    /// the draft next reads it too (#2584). Every reader asks, so a
    /// gate and the leave it calls both do: the request goes out once
    /// per chain, since a second commit in one turn re-commits a
    /// renamed Space against its old name.
    func commitFocusedField() {
        let id = ObjectIdentifier(self)
        guard committedThisTurn.insert(id).inserted else { return }
        NotificationCenter.default.post(
            name: .settingsCommitField,
            object: self
        )
        // A run-loop block, not a Task or the main queue: both wait
        // for the job running now to end.
        CFRunLoopPerformBlock(
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        ) {
            MainActor.assumeIsolated { _ = committedThisTurn.remove(id) }
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    /// ⌘S: commits the field being typed in, then saves when that
    /// leaves something to save.
    func saveFromKeyboard() {
        commitFocusedField()
        guard primarySaveEnabled else { return }
        performPrimarySave()
    }
}
