import KiwiDeskCore
import SwiftUI

/// Layout Defaults ▸ Monocle's animation rows (#1391): the card
/// flip's toggle and its duration, the scrolling pair's shape one
/// layout over (`LayoutCard+ScrollGrid`).
extension LayoutCard {
    var monocleFlipRow: some View {
        ToggleRow(
            label: L("monocle.flip", "Flip between windows"),
            isOn: $model.config.settings.animations.onMonocleFocus,
            help: LayoutHelp.monocleFlip
        )
    }

    var monocleFlipDurationRow: some View {
        StepperRow(
            label: L("monocle.flip_duration", "Flip duration"),
            value: $model.config.settings.animations
                .monocleFlipDurationMS,
            in: AnimationSettings.flipDurationBand,
            step: 10,
            suffix: "ms"
        )
    }
}
