import KiwiDeskCore
import SwiftUI

/// The Space Bar editor's size rows, split from
/// `SpaceBarGroups.swift` for the file ceiling (#520, which
/// added the editor-wide gate above them).
extension SpaceBarEditorGroup {
    // MARK: - Appearance

    @ViewBuilder var appearance: some View {
        PtSlider(
            label: L("space_bar.thickness", "Thickness"),
            value: style.thickness,
            range: 30...80
        )
        AutoGatedGroup(
            title: L(
                "space_bar.item_size.auto",
                "Auto item size"
            ),
            isOn: AutoSentinel.binding(
                style.itemSize,
                restore: 120
            )
        ) {
            PtSlider(
                label: L("space_bar.item_size", "Item size"),
                value: style.itemSize,
                range: 1...200,
                autoAtZero: true
            )
        }
        PtSlider(
            label: L("space_bar.item_gap", "Item gap"),
            value: style.itemGap,
            range: 0...40
        )
        AutoGatedGroup(
            title: L(
                "space_bar.font_size.auto",
                "Auto font size"
            ),
            isOn: AutoSentinel.binding(style.fontSize, restore: 14)
        ) {
            PtSlider(
                label: L("space_bar.font_size", "Font size"),
                value: style.fontSize,
                range: 1...32,
                autoAtZero: true
            )
        }
        StepperRow(
            label: L("space_bar.glyph_cap", "Glyphs per Space"),
            value: style.glyphCap,
            in: SpaceBarStyle.glyphCapRange,
            help: L(
                "space_bar.glyph_cap.help",
                "How many app glyphs a Space shows before the "
                    + "rest collapse into a +n badge. Adjacent "
                    + "windows of the same app count as one glyph."
            )
        )
        glyphCapSummary
        Divider()
        // Never greyed since background_fit: roundness
        // shapes the Boxed items, the glass plate, AND Plain's
        // own shared plate (BarPlate) — the old Plain grey
        // predated Plain getting a plate (QA 2026-07-19).
        PtSlider(
            label: L(
                "space_bar.corner_roundness",
                "Corner roundness"
            ),
            value: style.cornerRoundness,
            range: 0...100,
            unit: "%"
        )
    }
}
