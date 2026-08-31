import KiwiDeskCore
import SwiftUI

/// An editable space name. Commits the rename on Return or when
/// focus leaves; reverts to the current name if the new one is
/// empty or already taken, so a bad edit never renames.
struct SpaceNameField: View {
    let space: SpaceID
    let isAvailable: (SpaceID) -> Bool
    let onRename: (SpaceID) -> Void

    @State private var draft: String
    @FocusState private var focused: Bool

    init(
        space: SpaceID,
        isAvailable: @escaping (SpaceID) -> Bool,
        onRename: @escaping (SpaceID) -> Void
    ) {
        self.space = space
        self.isAvailable = isAvailable
        self.onRename = onRename
        _draft = State(initialValue: space.raw)
    }

    var body: some View {
        TextField("", text: $draft)
            .textFieldStyle(.roundedBorder)
            // Accessible label for nameless field (#812).
            .accessibilityLabel(
                L("diff.label.space_name", "Space name")
            )
            .fontWeight(.medium)
            .focused($focused)
            .frame(width: 180, alignment: .leading)
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
    }

    private func commit() {
        let target = SpaceID(draft.trimmed)
        guard target != space else {
            draft = space.raw
            return
        }
        guard !target.raw.isEmpty, isAvailable(target) else {
            draft = space.raw
            return
        }
        onRename(target)
    }
}
