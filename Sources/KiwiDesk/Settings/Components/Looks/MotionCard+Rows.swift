import KiwiDeskCore
import SwiftUI

/// Motion card row builders.
extension MotionCard {
    @ViewBuilder func motionRow(_ key: ColoursKey) -> some View {
        switch key {
        case .spaceTransition, .spaceScrollTransition,
            .spaceSlideDuration:
            let _ = assertionFailure(
                "\(key) is SpaceSwitchCard's row (#3218)"
            )
            EmptyView()
        case .animationSpeed:
            AnimationSpeedRow(model: model)
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
        case .animationsOnWindowResize:
            Toggle(
                L(
                    "behavior.animations.window_resize",
                    "Animate window resizes"
                ),
                isOn: animations.onWindowResize
            )
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.animateWindowResizes
            )
        case .animationsOnWindowSwap:
            Toggle(
                L(
                    "behavior.animations.window_swap",
                    "Animate window swaps"
                ),
                isOn: animations.onWindowSwap
            )
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.animateWindowSwaps
            )
        case .animationsOnRelayout:
            Toggle(
                L(
                    "behavior.animations.relayout",
                    "Animate layout reflows"
                ),
                isOn: animations.onRelayout
            )
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.animateLayoutReflows
            )
        case .animationsOnStateChange:
            ToggleRow(
                label: L(
                    "behavior.animations.state_change",
                    "Animate float, Pocket & maximize"
                ),
                isOn: animations.onStateChange,
                help: L(
                    "behavior.animations.state_change.help",
                    "A window floating or tiling, maximizing or "
                        + "returning, or going into the Pocket and "
                        + "out moves there instead of jumping. "
                        + "The windows around it follow %1$@.",
                    L(
                        "behavior.animations.relayout",
                        "Animate layout reflows"
                    )
                )
            )
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.animateStateChanges
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
