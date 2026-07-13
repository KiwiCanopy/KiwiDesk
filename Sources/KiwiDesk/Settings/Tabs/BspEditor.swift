import KiwiDeskCore
import SwiftUI

/// BSP tuning — one mode's tab in Layout Defaults (#204). Split
/// out of the former `LayoutParamsEditor` at the mode boundary
/// so each mode hosts its own tab and schematic (#125); the
/// shared row vocabulary lives in `SettingsRows`.
struct BspEditor: View {
    @ObservedObject var model: SettingsModel

    private var bsp: Binding<BspParams> {
        $model.config.settings.bsp
    }

    var body: some View {
        SettingsSection(
            L("layout.bsp.name", "Bsp"),
            symbol: LayoutMode.bsp.glyph
        ) {
            BspSchematic(
                splitRatioH: model.config.settings.bsp.splitRatioH,
                splitRatioV: model.config.settings.bsp.splitRatioV,
                strategy: model.config.settings.bsp.strategy,
                placement: model.config.settings.bsp
                    .newWindowPlacement
            )
            SegmentedPicker(
                L("layout_params.split_strategy", "Split strategy"),
                selection: bsp.strategy,
                options: [
                    (
                        L(
                            "layout_params.longest_side",
                            "Longest side"
                        ),
                        BspParams.Strategy.longestSide
                    ),
                    (
                        L(
                            "layout_params.alternating",
                            "Alternating"
                        ), .alternating
                    ),
                ]
            )
            RatioRow(
                label: L(
                    "layout_params.split_ratio_h",
                    "Width split ratio"
                ),
                value: bsp.splitRatioH
            )
            RatioRow(
                label: L(
                    "layout_params.split_ratio_v",
                    "Height split ratio"
                ),
                value: bsp.splitRatioV
            )
            Divider()
            PlacementPicker(placement: bsp.newWindowPlacement)
        }
    }
}
