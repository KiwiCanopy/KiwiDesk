import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Behavior (#68 §3.2): mouse-resize mode and
/// the general-purpose animation toggles + duration —
/// per-profile data, labeled as such by the sidebar group
/// (the old General tab presented them without any scope cue).
/// The Scrolling focus-shift toggle and its speed live with
/// the scrolling layout's own parameters (§3.5), not here.
struct BehaviorSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mouseSection
                animationsSection
            }
            .padding(16)
        }
    }

    private var mouseSection: some View {
        SettingsSection("Mouse") {
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
        }
    }

    private var animationsSection: some View {
        SettingsSection("Animations") {
            Toggle(
                "Virtual space switches",
                isOn: $model.config.settings.animations
                    .onSpaceChange
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
            durationRow
            Text(
                "Scrolling-layout focus shifts have their own "
                    + "toggle and speed under Spaces ▸ "
                    + "Scrolling."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// Stepper for the general animation duration
    /// (`animations.duration`; `animations.set_duration` Lua)
    /// — paces exactly the four toggles above (#51).
    private var durationRow: some View {
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
}
