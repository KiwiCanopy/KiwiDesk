import KiwiDeskCore
import SwiftUI

/// The KiwiShelf card's row builders, one per census row; the
/// Auto/value font pair renders at the Auto key as one
/// `AutoGatedGroup`, so the value key builds nothing of its own.
extension KiwiShelfCard {
    @ViewBuilder func kiwishelfRow(_ key: KiwiShelfKey) -> some View {
        switch key {
        case .edge:
            SegmentedPicker(
                L("kiwishelf.edge.label", "Position"),
                selection: shelf.edge,
                options: AppBarOptions.edge.map { ($0.1, $0.0) },
                help: L(
                    "kiwishelf.edge.label.help",
                    "Which screen edge KiwiShelf occupies. It "
                        + "reserves that edge in every layout, "
                        + "whichever bars it shows."
                )
            )
        case .thickness:
            PtSlider(
                label: L("kiwishelf.thickness", "Thickness"),
                value: shelf.thickness,
                range: BarSliderBands.thickness,
                help: L(
                    "kiwishelf.thickness.help",
                    "One thickness for both bars. An automatic "
                        + "font size follows it."
                )
            )
        case .alignment:
            alignmentRow
        case .order:
            orderRow
        case .share:
            shareRow
        case .background:
            backgroundStyleRow
        case .backgroundFit:
            backgroundFitRow
        case .cornerRoundness:
            PtSlider(
                label: L(
                    "kiwishelf.corner_roundness",
                    "Corner roundness"
                ),
                value: shelf.cornerRoundness,
                range: 0...100,
                unit: "%",
                help: L(
                    "kiwishelf.corner_roundness.help",
                    "Rounds the plates and every item box — both "
                        + "bars alike."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfStyle.children
                    .kiwishelfStyleCornerRoundness
            )
        case .itemGap:
            PtSlider(
                label: L("kiwishelf.item_gap", "Item gap"),
                value: shelf.itemGap,
                range: 0...40,
                help: L(
                    "kiwishelf.item_gap.help",
                    "Room between items — Space items and App Bar "
                        + "items alike, so both bars keep one "
                        + "rhythm."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfStyle.children
                    .kiwishelfStyleItemGap
            )
        case .fontSizeAuto:
            fontSizeGroup
        case .outerMargin:
            PtSlider(
                label: L("kiwishelf.outer_margin", "Outer margin"),
                value: shelf.outerMargin,
                range: BarSliderBands.margin,
                help: L(
                    "kiwishelf.outer_margin.help",
                    "Distance from the screen edge; 0 is flush."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfMargins.children
                    .kiwishelfOuterMargin
            )
        case .innerMargin:
            PtSlider(
                label: L("kiwishelf.inner_margin", "Inner margin"),
                value: shelf.innerMargin,
                range: BarSliderBands.margin,
                help: L(
                    "kiwishelf.inner_margin.help",
                    "Extra room on the side facing the windows, on "
                        + "top of whatever gap already sits there; "
                        + "0 lets that gap govern."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfMargins.children
                    .kiwishelfInnerMargin
            )
        case .fontSize, .liquidGlass:
            EmptyView()
        }
    }

    private var backgroundStyleRow: some View {
        SegmentedPicker(
            L(
                "kiwishelf.background_style.label",
                "Background style"
            ),
            selection: shelf.backgroundStyle,
            options: AppBarOptions.backgroundStyle
                .map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.background_style.label.help",
                "\u{201C}%1$@\u{201D} draws one plate behind each "
                    + "bar's items; \u{201C}%2$@\u{201D} draws a "
                    + "box per item and no plate.",
                L("app_bar.background_style.plain", "Plain"),
                L("app_bar.background_style.boxed", "Boxed")
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleBackground
        )
    }

    private var backgroundFitRow: some View {
        SegmentedPicker(
            L(
                "kiwishelf.background_fit.label",
                "Background size"
            ),
            selection: shelf.backgroundFit,
            options: AppBarOptions.backgroundFit
                .map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.background_fit.label.help",
                "\u{201C}%1$@\u{201D}: each bar's plate fits its "
                    + "items, in its own fill. \u{201C}%2$@\u{201D}: "
                    + "one plate spans the edge, blending from the "
                    + "Space Bar's fill to the App Bar's.",
                L("app_bar.background_fit.hug", "Hug"),
                L("app_bar.background_fit.full", "Full width")
            )
        )
        .modifier(
            GreyOut(
                active: shelf.wrappedValue.backgroundStyle == .boxed,
                help: L(
                    "space_bar.background_fit.boxed_only",
                    "\u{201C}%1$@\u{201D} draws a box per item, "
                        + "not a shared plate, so there is "
                        + "nothing to size.",
                    L("app_bar.background_style.boxed", "Boxed")
                )
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleBackgroundFit
        )
    }

    private var fontSizeGroup: some View {
        AutoGatedGroup(
            title: L("kiwishelf.font_size.auto", "Auto font size"),
            isOn: AutoSentinel.binding(shelf.fontSize, restore: 14),
            caption: L(
                "kiwishelf.font_size.help",
                "One size for both bars, so Space numbers and App "
                    + "Bar titles line up. Automatic follows the "
                    + "thickness."
            )
        ) {
            PtSlider(
                label: L("kiwishelf.font_size", "Font size"),
                value: shelf.fontSize,
                range: 1...32,
                autoAtZero: true
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfStyle.children
                    .kiwishelfStyleFontSize
            )
        }
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleFontSizeAuto
        )
    }
}
