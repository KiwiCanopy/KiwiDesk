import KiwiDeskCore
import SwiftUI

/// Motion card row builders.
extension MotionCard {
    @ViewBuilder func motionRow(_ key: ColoursKey) -> some View {
        switch key {
        case .animationsMaster:
            ToggleRow(
                label: L(
                    "behavior.animations.master",
                    "Animate windows"
                ),
                isOn: animationsMasterBinding,
                help: L(
                    "behavior.animations.master.help",
                    "The master switch for KiwiDesk's window "
                        + "animations. Off snaps windows into "
                        + "place instantly. Turning macOS "
                        + "System Settings ▸ Accessibility ▸ "
                        + "Reduce Motion on also keeps them off."
                )
            )
        case .animationsOnSpaceChange:
            Toggle(
                L(
                    "behavior.animations.space_change",
                    "Animate Space switches"
                ),
                isOn: animations.onSpaceChange
            )
            // Coordinated out+in transition caption (#207).
            Text(
                L(
                    "behavior.animations.space_change.caption",
                    "Windows slide out of the Space you're "
                        + "leaving and into the one you're "
                        + "switching to."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        case .animationsOnWindowResize:
            Toggle(
                L(
                    "behavior.animations.window_resize",
                    "Animate window resizes"
                ),
                isOn: animations.onWindowResize
            )
        case .animationsOnWindowSwap:
            Toggle(
                L(
                    "behavior.animations.window_swap",
                    "Animate window swaps"
                ),
                isOn: animations.onWindowSwap
            )
        case .animationsOnRelayout:
            Toggle(
                L(
                    "behavior.animations.relayout",
                    "Animate layout reflows"
                ),
                isOn: animations.onRelayout
            )
        case .animationsDurationMS:
            Divider()
            // Paces the animation toggles above (#51).
            StepperRow(
                label: L("behavior.animations.duration", "Duration"),
                value: animations.durationMS,
                in: 50...1000,
                step: 10,
                suffix: "ms"
            )
        default:
            let _ = assertionFailure(
                "non-Motion Colours key in the Motion card: "
                    + key.rawValue
            )
            EmptyView()
        }
    }

    var animations: Binding<AnimationSettings> {
        $model.config.settings.animations
    }
}
