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
        case .minimum:
            minimumRow
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
        case .highlightWidth:
            highlightWidthRow
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
        case .iconSource:
            iconSourceRow
        case .fontSize, .liquidGlass, .dimFactor, .fillColor,
            .itemColor, .activeItemColor, .highlightColor,
            .hoverFillColor, .hoverItemColor, .groupBadgeColor,
            .groupBadgeTextColor:
            EmptyView()
        }
    }

    /// App icon rendering for both bars (#294, #1517): one app is
    /// never drawn in two styles on one plate. Greys only while
    /// no bar draws an app icon.
    private var iconSourceRow: some View {
        DropdownRow(
            label: L("kiwishelf.icon_source.label", "App symbol style"),
            spokenValue: AppBarOptions.iconSourceTitle(
                shelf.iconSource.wrappedValue
            ),
            // Interpolated labels (#818).
            help: L(
                "kiwishelf.icon_source.help",
                "How app icons are drawn on both bars. "
                    + "\u{201C}%1$@\u{201D} shows a monochrome "
                    + "symbol colored by KiwiShelf's item colors, "
                    + "set in %2$@; apps without a symbol keep "
                    + "their app icon.",
                L("app_bar.icon_source.app_font", "Glyphs"),
                SettingsDestination.advancedColors.title
            )
        ) {
            Picker(
                L("kiwishelf.icon_source.label", "App symbol style"),
                selection: shelf.iconSource
            ) {
                ForEach(AppBarOptions.iconSource, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
        }
        .modifier(
            GreyOut(
                active: gates.noBarDrawsIcon,
                help: BarsGateHelp.sentence(for: .noAppIcon)
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleIconSource
        )
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
                    + "items. \u{201C}%2$@\u{201D}: each bar's plate "
                    + "spans its whole part of the edge. Each keeps "
                    + "its own fill.",
                L("app_bar.background_fit.hug", "Hug"),
                L("app_bar.background_fit.full", "Full")
            )
        )
        .modifier(
            GreyOut(
                active: gates.boxedShelf,
                help: BarsGateHelp.sentence(for: .boxedShelf)
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
