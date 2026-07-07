import KiwiDeskCore
import SwiftUI

/// Tab 3 — Spaces: global gaps, the list of defined virtual
/// spaces (add / name / pick a layout), and the per-layout
/// tuning below (05_GUI_Concept §2, Tab 3).
struct SpacesTab: View {
    @ObservedObject var model: SettingsModel
    @State private var newSpace = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                minSizeSection
                GapsEditor(model: model)
                spacesSection
                SpaceOverridesEditor(model: model)
                layoutHeader
                LayoutParamsEditor(model: model)
                ScrollGridEditor(model: model)
                MonocleEditor(model: model)
                DragVisualsEditor(model: model)
            }
            .padding(16)
        }
    }

    private var minSizeSection: some View {
        SettingsSection("Minimum window size") {
            HStack {
                Slider(
                    value: $model.config.settings.minWindowSize,
                    in: 100...800,
                    step: 10
                )
                Text(
                    "\(Int(model.config.settings.minWindowSize))"
                        + " pt"
                )
                .frame(width: 56, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
            }
        }
    }

    // MARK: - Spaces

    private var spacesSection: some View {
        SettingsSection("Spaces") {
            Text(
                "Each space has its own layout. Add spaces here; "
                    + "they appear in the shortcut and app-rule "
                    + "lists too."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(model.config.spaces, id: \.raw) { space in
                spaceRow(space)
            }
            addRow
        }
    }

    private func spaceRow(_ space: SpaceID) -> some View {
        HStack {
            SpaceNameField(
                space: space,
                isAvailable: { !model.config.spaces.contains($0) },
                onRename: { renameSpace(space, to: $0) }
            )
            Spacer()
            Picker("", selection: modeBinding(space)) {
                ForEach(LayoutMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            Button {
                removeSpace(space)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
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

    private var layoutHeader: some View {
        Text("Layout Specific Settings")
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.top, 4)
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
    }

    /// Renames a space, migrating its mode, app rules, monitor
    /// map, and keybinding references (`GuiConfig.renameSpace`).
    private func renameSpace(_ space: SpaceID, to target: SpaceID) {
        model.config.renameSpace(from: space, to: target)
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
private struct SpaceNameField: View {
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
