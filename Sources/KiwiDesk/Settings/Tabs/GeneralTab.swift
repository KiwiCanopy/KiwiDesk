import KiwiDeskCore
import SwiftUI

/// Tab 2 — General: behavior tuning (mouse resize, animations) and
/// advanced settings (05_GUI_Concept §2, Tab 2).
struct GeneralTab: View {
    @ObservedObject var model: SettingsModel
    /// Advanced is collapsed by default — only interested users
    /// need the config-file path and the raw Lua editor.
    @State private var advancedExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                behaviorSection
                advancedSection
            }
            .padding(16)
        }
    }

    private var behaviorSection: some View {
        SettingsSection("General behavior") {
            Picker(
                "Mouse resize action",
                selection: $model.config.settings.mouseResize
            ) {
                Text("Resize adjacent windows")
                    .tag(MouseResizeMode.layout)
                Text("Snap back to slot")
                    .tag(MouseResizeMode.snapBack)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Animations")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.secondary)

                Toggle(
                    "Virtual space switches",
                    isOn: $model.config.settings.animations
                        .onSpaceChange
                )
                Toggle(
                    "Scrolling space focus shifts",
                    isOn: $model.config.settings.animations
                        .onScrolling
                )
                Toggle(
                    "Window resizes",
                    isOn: $model.config.settings.animations
                        .onWindowResize
                )
                Toggle(
                    "Window swaps",
                    isOn: $model.config.settings.animations
                        .onWindowSwap
                )
                Toggle(
                    "Layout reflows",
                    isOn: $model.config.settings.animations
                        .onRelayout
                )
            }
        }
    }

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $advancedExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(model.configURL.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Reveal") {
                        NSWorkspace.shared
                            .activateFileViewerSelecting(
                                [model.configURL]
                            )
                    }
                }
                Divider()
                Button {
                    model.showLuaEditor = true
                } label: {
                    Label(
                        "Edit init.lua directly",
                        systemImage: "curlybraces"
                    )
                }
                Text(
                    "Opens the integrated Lua editor for custom "
                        + "scripting beyond the visual controls."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Advanced").font(.headline)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

/// A titled group used across the dashboard tabs.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }
}
