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
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.animateSpaceSwitches
            )
            // The plate slide (#1956).
            Text(
                L(
                    "behavior.animations.space_change.caption",
                    "Plates cover your windows and slide to the "
                        + "Space you're switching to."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            // The window toggles and their duration form one group
            // apart from the slide, which it does not pace (#1932).
            Divider()
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
        case .animationsDurationMS:
            // Paces the window toggles above and the window moves
            // no toggle governs, so it greys only with the master
            // (#51, #1932).
            StepperRow(
                label: L(
                    "behavior.animations.window_duration",
                    "Window duration"
                ),
                value: animations.durationMS,
                in: AnimationSettings.durationBand,
                step: 10,
                suffix: "ms",
                help: L(
                    "behavior.animations.window_duration.help",
                    "How long a window takes to reach its new place "
                        + "when it moves, resizes, swaps or reflows. A "
                        + "longer duration is slower."
                )
            )
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.animationDuration
            )
        case .animationsOnShelf:
            ToggleRow(
                label: L("behavior.animations.shelf", "Animate KiwiShelf"),
                isOn: animations.onShelf,
                help: L(
                    "behavior.animations.shelf.help",
                    "While both bars share an edge, the App Bar "
                        + "grows out of the Space Bar and shrinks back "
                        + "into it; a bar on an edge of its own fades "
                        + "in and out; the bars glide to their new "
                        + "places. Off, or with Reduce Motion on, "
                        + "they move at once."
                )
            )
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.animateShelf
            )
        case .animationsShelfDurationMS:
            StepperRow(
                label: L(
                    "behavior.animations.shelf_duration",
                    "KiwiShelf duration"
                ),
                value: animations.shelfDurationMS,
                in: AnimationSettings.shelfDurationBand,
                step: 50,
                suffix: "ms",
                help: L(
                    "behavior.animations.shelf_duration.help",
                    "How long the bars take to grow, shrink, fade "
                        + "and glide into place."
                )
            )
            .modifier(GreyOut(active: !animations.onShelf.wrappedValue))
            .searchAnchored(
                SettingsCatalog.colors.motionMore.children.shelfDuration
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
