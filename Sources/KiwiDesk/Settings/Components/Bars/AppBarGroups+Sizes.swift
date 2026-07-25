import KiwiDeskCore
import SwiftUI

/// The global App Bar editor's size rows, split from
/// `AppBarGroups.swift` for the file ceiling (#520, which added
/// the editor-wide gate above them).
extension GlobalAppBarGroup {
    // Ordered thickness → the two Auto-gated size pairs
    // (`AutoGatedGroup`: the toggle bound directly above the slider
    // it owns) → a divider → corner roundness (gated by a different
    // switch, Tab background). "Auto" size/font is a GUI face on the
    // model's 0 = auto sentinel: the toggle greys its slider and
    // stores 0; turning it off restores a sensible non-zero value
    // (#171 grey-out).
    @ViewBuilder var appearance: some View {
        PtSlider(
            label: L("app_bar.thickness", "Thickness"),
            value: $style.thickness,
            range: 30...80
        )
        AutoGatedGroup(
            title: L("app_bar.box_size.auto", "Auto box size"),
            isOn: AppBarAuto.binding($style.boxSize, restore: 120)
        ) {
            PtSlider(
                label: L("app_bar.box_size", "Box size"),
                value: $style.boxSize,
                range: 1...200,
                autoAtZero: true
            )
        }
        PtSlider(
            label: L("app_bar.box_gap", "Box gap"),
            value: $style.boxGap,
            range: 0...40
        )
        AutoGatedGroup(
            title: L("app_bar.font_size.auto", "Auto font size"),
            isOn: AppBarAuto.binding($style.fontSize, restore: 14)
        ) {
            PtSlider(
                label: L("app_bar.font_size", "Font size"),
                value: $style.fontSize,
                range: 1...32,
                autoAtZero: true
            )
        }
        Divider()
        // Never greyed since tab_background_fit: roundness
        // shapes the Boxed tabs, the glass plate, AND Plain's
        // own shared plate (BarPlate) — the old Plain grey
        // predated Plain getting a plate (QA 2026-07-19).
        PtSlider(
            label: L("app_bar.corner_roundness", "Corner roundness"),
            value: $style.cornerRoundness,
            range: 0...100,
            unit: "%"
        )
    }
}
