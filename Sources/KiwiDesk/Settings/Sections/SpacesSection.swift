import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Spaces (#68 §3.2/§3.3): the profile's space
/// list — rename, reorder (drag or context menu), pick a layout
/// mode (with its glyph), designate the fallback space, and
/// tune per-space overrides inline on each row.
struct SpacesSection: View {
    @ObservedObject var model: SettingsModel
    @State private var newSpace = ""
    /// Rows with an open "Customize" expander.
    @State private var expanded: Set<SpaceID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                spacesSection
            }
            .padding(16)
        }
    }

    private var spacesSection: some View {
        SettingsSection("Spaces") {
            Text(
                "Each space has its own layout. Add spaces "
                    + "here; they appear in the shortcut and "
                    + "app-rule lists too. Drag rows to "
                    + "reorder."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(
                "When you switch profiles, windows from a "
                    + "space the new profile doesn't have "
                    + "land in its fallback space (the first "
                    + "space when none is chosen)."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(model.config.spaces, id: \.raw) { space in
                spaceRow(space)
            }
            addRow
        }
    }

    // MARK: - Rows

    private func spaceRow(_ space: SpaceID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .help("Drag to reorder")
                SpaceNameField(
                    space: space,
                    isAvailable: {
                        !model.config.spaces.contains($0)
                    },
                    onRename: {
                        model.config.renameSpace(
                            from: space,
                            to: $0
                        )
                    }
                )
                if model.config.fallbackSpace == space {
                    BadgeChip(label: "Fallback")
                        .help(
                            "Windows from a removed space "
                                + "land here when you switch "
                                + "profiles."
                        )
                }
                Spacer()
                modePicker(space)
                expandButton(space)
                Button {
                    removeSpace(space)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            if expanded.contains(space) {
                SpaceOverrideRows(model: model, space: space)
                    .padding(.leading, 24)
                    .padding(.bottom, 4)
            }
            Divider()
        }
        .contextMenu { contextActions(space) }
        .draggable(DraggableSpace(raw: space.raw))
        .dropDestination(for: DraggableSpace.self) {
            dropped,
            _ in
            guard let first = dropped.first else {
                return false
            }
            move(SpaceID(first.raw), before: space)
            return true
        }
    }

    private func modePicker(_ space: SpaceID) -> some View {
        Picker("", selection: modeBinding(space)) {
            ForEach(LayoutMode.allCases, id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.glyph)
                    .tag(mode)
            }
        }
        .labelsHidden()
        .frame(width: 150)
    }

    private func expandButton(_ space: SpaceID) -> some View {
        Button {
            if expanded.contains(space) {
                expanded.remove(space)
            } else {
                expanded.insert(space)
            }
        } label: {
            Image(
                systemName: expanded.contains(space)
                    ? "chevron.down" : "slider.horizontal.3"
            )
        }
        .buttonStyle(.borderless)
        .help("Customize this space")
    }

    /// Keyboard-reachable equivalents of the drag/badge
    /// affordances (the §3.13 accessibility pattern).
    @ViewBuilder
    private func contextActions(_ space: SpaceID) -> some View {
        if model.config.fallbackSpace == space {
            Button("Clear Fallback") {
                model.config.fallbackSpace = nil
            }
        } else {
            Button("Make Fallback") {
                model.config.fallbackSpace = space
            }
        }
        Divider()
        Button("Move Up") { nudge(space, by: -1) }
            .disabled(index(of: space) == 0)
        Button("Move Down") { nudge(space, by: 1) }
            .disabled(
                index(of: space)
                    == model.config.spaces.count - 1
            )
        Divider()
        Button("Delete", role: .destructive) {
            removeSpace(space)
        }
    }

    private var addRow: some View {
        HStack {
            TextField("New space name", text: $newSpace)
                .textFieldStyle(.roundedBorder)
            Button {
                addSpace()
            } label: {
                Image(systemName: "plus")
            }
            .disabled(!canAdd)
        }
    }

    // MARK: - Mutations

    private var canAdd: Bool {
        let name = newSpace.trimmed
        return !name.isEmpty
            && !model.config.spaces.contains { $0.raw == name }
    }

    private func addSpace() {
        guard canAdd else { return }
        model.config.spaces.append(SpaceID(newSpace.trimmed))
        newSpace = ""
    }

    private func removeSpace(_ space: SpaceID) {
        model.config.spaces.removeAll { $0 == space }
        model.config.spaceModes[space] = nil
        expanded.remove(space)
        if model.config.fallbackSpace == space {
            model.config.fallbackSpace = nil
        }
    }

    private func index(of space: SpaceID) -> Int {
        model.config.spaces.firstIndex(of: space) ?? 0
    }

    private func nudge(_ space: SpaceID, by delta: Int) {
        let from = index(of: space)
        let to = from + delta
        guard model.config.spaces.indices.contains(to) else {
            return
        }
        model.config.spaces.swapAt(from, to)
    }

    /// Reorder-by-drop: inserts `moved` in front of `anchor`.
    private func move(_ moved: SpaceID, before anchor: SpaceID) {
        guard moved != anchor,
            let from = model.config.spaces.firstIndex(
                of: moved
            ),
            let to = model.config.spaces.firstIndex(of: anchor)
        else { return }
        var spaces = model.config.spaces
        spaces.remove(at: from)
        let insertion = spaces.firstIndex(of: anchor) ?? to
        spaces.insert(moved, at: insertion)
        model.config.spaces = spaces
    }

    /// Setting a space to the default `bsp` removes its entry
    /// (the writer treats absent as `bsp`).
    private func modeBinding(
        _ space: SpaceID
    ) -> Binding<LayoutMode> {
        Binding(
            get: { model.config.spaceModes[space] ?? .bsp },
            set: { mode in
                model.config.spaceModes[space] =
                    mode == .bsp ? nil : mode
            }
        )
    }
}

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
            .textFieldStyle(.plain)
            .fontWeight(.medium)
            .focused($focused)
            .frame(maxWidth: 200, alignment: .leading)
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
