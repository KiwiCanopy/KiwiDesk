import KiwiDeskCore
import SwiftUI

/// The global App Bar editor's size rows, split from
/// `AppBarGroups.swift` for the file ceiling (#520, which added
/// the editor-wide gate above them).
extension GlobalAppBarGroup {
    // Ordered thickness → the two Auto-gated size pairs
    // (`AutoGatedGroup`: the toggle bound directly above the slider
    // it owns) → a divider → corner roundness (gated by a different
    // switch, Background style). "Auto" size/font is a GUI face
    // on the model's 0 = auto sentinel: the toggle greys its
    // slider and stores 0; turning it off restores a sensible
    // non-zero value (#171 grey-out).
    @ViewBuilder var appearance: some View {
        PtSlider(
            label: L("app_bar.thickness", "Thickness"),
            value: $style.thickness,
            range: 30...80
        )
        AutoGatedGroup(
            title: L("app_bar.item_size.auto", "Auto item size"),
            isOn: AutoSentinel.binding($style.itemSize, restore: 120)
        ) {
            PtSlider(
                label: L("app_bar.item_size", "Item size"),
                value: $style.itemSize,
                range: 1...200,
                autoAtZero: true
            )
        }
        PtSlider(
            label: L("app_bar.item_gap", "Item gap"),
            value: $style.itemGap,
            range: 0...40
        )
        AutoGatedGroup(
            title: L("app_bar.font_size.auto", "Auto font size"),
            isOn: AutoSentinel.binding($style.fontSize, restore: 14)
        ) {
            PtSlider(
                label: L("app_bar.font_size", "Font size"),
                value: $style.fontSize,
                range: 1...32,
                autoAtZero: true
            )
        }
        Divider()
        // Never greyed since background_fit: roundness
        // shapes the Boxed items, the glass plate, AND Plain's
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
