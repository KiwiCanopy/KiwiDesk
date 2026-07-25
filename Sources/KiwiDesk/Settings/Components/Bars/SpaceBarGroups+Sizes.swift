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
                "space_bar.box_size.auto",
                "Auto box size"
            ),
            isOn: AppBarAuto.binding(
                style.boxSize,
                restore: 120
            )
        ) {
            PtSlider(
                label: L("space_bar.box_size", "Box size"),
                value: style.boxSize,
                range: 1...200,
                autoAtZero: true
            )
        }
        PtSlider(
            label: L("space_bar.box_gap", "Box gap"),
            value: style.boxGap,
            range: 0...40
        )
        AutoGatedGroup(
            title: L(
                "space_bar.font_size.auto",
                "Auto font size"
            ),
            isOn: AppBarAuto.binding(style.fontSize, restore: 14)
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
        // Never greyed since tab_background_fit: roundness
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
