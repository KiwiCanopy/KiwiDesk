import KiwiDeskCore
import SwiftUI

/// Tab 4 — App Automation: pin apps to spaces (`app_rules`) and
/// list windows that should never tile (`float_rules`). Apps are
/// chosen from a dropdown (with a Custom fallback); spaces can
/// only be existing ones (05_GUI_Concept §2, Tab 4).
struct AppRulesTab: View {
    @ObservedObject var model: SettingsModel
    @State private var newApp = ""
    @State private var newSpace: SpaceID?
    @State private var newFloat = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                assignmentSection
                floatSection
            }
            .padding(16)
        }
    }

    private var spaces: [SpaceID] { model.config.spaces }

    // MARK: - App -> space assignment

    private var assignmentSection: some View {
        SettingsSection("Assignment rules") {
            Text("Send an app's windows to a fixed space.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(sortedApps, id: \.self) { app in
                HStack {
                    Text(app)
                    Spacer()
                    SpaceMenu(
                        spaces: spaces,
                        selected: model.config.appRules[app]
                    ) { model.config.appRules[app] = $0 }
                    Button {
                        model.config.appRules[app] = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            addAssignmentRow
        }
    }

    private var addAssignmentRow: some View {
        HStack {
            AppSelector(name: $newApp)
            Spacer()
            SpaceMenu(spaces: spaces, selected: newSpace) {
                newSpace = $0
            }
            Button {
                addAssignment()
            } label: {
                Image(systemName: "plus")
            }
            .disabled(newApp.trimmed.isEmpty || newSpace == nil)
        }
    }

    // MARK: - Float rules

    private var floatSection: some View {
        SettingsSection("Never tile (float rules)") {
            Text(
                "Choose an app, or use Custom for an app-and-"
                    + "title pattern like \"Finder:Get Info\"."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(model.config.floatRules, id: \.self) { rule in
                HStack {
                    Text(rule)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button {
                        removeFloat(rule)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                AppSelector(name: $newFloat)
                Spacer()
                Button {
                    addFloat()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(newFloat.trimmed.isEmpty)
            }
        }
    }

    // MARK: - Mutations

    private var sortedApps: [String] {
        model.config.appRules.keys.sorted()
    }

    private func addAssignment() {
        guard let space = newSpace else { return }
        model.config.appRules[newApp.trimmed] = space
        newApp = ""
        newSpace = nil
    }

    private func addFloat() {
        let rule = newFloat.trimmed
        newFloat = ""
        guard !model.config.floatRules.contains(rule) else {
            return
        }
        model.config.floatRules.append(rule)
    }

    private func removeFloat(_ rule: String) {
        model.config.floatRules.removeAll { $0 == rule }
    }
}
