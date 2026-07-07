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
                // The advanced block reveals and edits the global
                // init.lua — hidden while editing a stored profile
                // (that mode writes only the profile JSON, #18).
                if !model.editingStoredProfile {
                    advancedSection
                }
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
                Divider()
                animationDurationRow
                scrollSpeedRow
            }
        }
    }

    /// Stepper for the general animation duration
    /// (`animations.duration` JSON; `animations.set_duration` Lua).
    private var animationDurationRow: some View {
        let ms = model.config.settings.animations.durationMS
        return HStack {
            Text("Duration")
            Spacer()
            Stepper(
                value: $model.config.settings.animations
                    .durationMS,
                in: 50...1000,
                step: 10
            ) {
                Text("\(ms) ms")
                    .frame(minWidth: 52, alignment: .trailing)
                    .monospacedDigit()
            }
        }
    }

    /// Stepper for the scrolling-layout focus-shift speed
    /// (`animations.scroll_speed` JSON;
    /// `animations.set_scroll_speed` Lua — issue #51).
    private var scrollSpeedRow: some View {
        let ms = model.config.settings.animations.scrollSpeedMS
        return HStack {
            Text("Scroll speed")
            Spacer()
            Stepper(
                value: $model.config.settings.animations
                    .scrollSpeedMS,
                in: 50...1000,
                step: 10
            ) {
                Text("\(ms) ms")
                    .frame(minWidth: 52, alignment: .trailing)
                    .monospacedDigit()
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
