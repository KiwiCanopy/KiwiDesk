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
        SettingsSection(L("behavior.mouse.title", "Mouse")) {
            SegmentedPicker(
                L(
                    "behavior.mouse.resize_action",
                    "Mouse resize action"
                ),
                selection: $model.config.settings
                    .mouseResize,
                options: [
                    (
                        L(
                            "behavior.mouse.resize_layout",
                            "Resize adjacent windows"
                        ),
                        MouseResizeMode.layout
                    ),
                    (
                        L(
                            "behavior.mouse.resize_snap_back",
                            "Snap back to slot"
                        ), .snapBack
                    ),
                ]
            )
        }
    }

    private var animationsSection: some View {
        SettingsSection(
            L("behavior.animations.title", "Animations")
        ) {
            Toggle(
                L(
                    "behavior.animations.space_change",
                    "Animate virtual space switches"
                ),
                isOn: $model.config.settings.animations
                    .onSpaceChange
            )
            Toggle(
                L(
                    "behavior.animations.window_resize",
                    "Animate window resizes"
                ),
                isOn: $model.config.settings.animations
                    .onWindowResize
            )
            Toggle(
                L(
                    "behavior.animations.window_swap",
                    "Animate window swaps"
                ),
                isOn: $model.config.settings.animations
                    .onWindowSwap
            )
            Toggle(
                L(
                    "behavior.animations.relayout",
                    "Animate layout reflows"
                ),
                isOn: $model.config.settings.animations
                    .onRelayout
            )
            Divider()
            durationRow
            CrossReferenceRow(
                prose: L(
                    "behavior.animations.scrolling_xref",
                    "Scrolling-layout focus shifts have "
                        + "their own toggle and speed in"
                ),
                linkTitle: L(
                    "behavior.animations.scrolling_xref_link",
                    "Layout Defaults ▸ Scrolling"
                ),
                destination: .layoutDefaults
            )
        }
    }

    /// Stepper for the general animation duration
    /// (`animations.duration`; `animations.set_duration` Lua)
    /// — paces exactly the four toggles above (#51).
    private var durationRow: some View {
        let ms = model.config.settings.animations.durationMS
        let durationLabel = L(
            "behavior.animations.duration",
            "Duration"
        )
        return HStack {
            Text(durationLabel)
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
            .controlSize(.large)
            .accessibilityLabel(durationLabel)
            .accessibilityValue("\(ms) ms")
        }
    }
}
