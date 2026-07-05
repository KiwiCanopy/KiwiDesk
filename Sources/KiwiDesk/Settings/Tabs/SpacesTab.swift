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
            Text(space.raw)
                .fontWeight(.medium)
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
