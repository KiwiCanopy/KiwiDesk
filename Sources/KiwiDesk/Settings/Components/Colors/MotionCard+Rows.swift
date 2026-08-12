import KiwiDeskCore
import SwiftUI

/// The Motion card's per-key controls. Same English as the
/// Behavior card they moved from, so the eleven translations
/// carry over; this file is now their only
/// `scripts/extract-keys`-visible call site.
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
            // Retires the entrance-only mental image (#207):
            // the transition is a coordinated out+in.
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
            // Paces exactly the four toggles above (#51).
            StepperRow(
                label: L("behavior.animations.duration", "Duration"),
                value: animations.durationMS,
                in: 50...1000,
                step: 10,
                suffix: "ms"
            )
        default:
            // Palette and scrolling rows share the `ColoursKey`
            // slice but belong to other containers; the
            // render-parity guard keeps them out of the order
            // lists, so reaching here is a placement bug.
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
