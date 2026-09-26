import KiwiDeskCore
import SwiftUI

/// The KiwiShelf Style drawer's Border rows (#1679): the switch,
/// and its width greyed while it is off. The colour is Advanced
/// Colours' (a colour renders in one area).
extension KiwiShelfCard {
    var borderRow: some View {
        ToggleRow(
            label: L("kiwishelf.border", "Border"),
            isOn: shelf.border,
            help: L(
                "kiwishelf.border.help",
                "A thin line around the plate, or around each box "
                    + "when the background is \u{201C}%1$@\u{201D}. "
                    + "Its color is set in %2$@.",
                L("app_bar.background_style.boxed", "Boxed"),
                SettingsDestination.advancedColors.title
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleBorder
        )
    }

    var borderWidthRow: some View {
        PtSlider(
            label: L("kiwishelf.border_width", "Border width"),
            value: shelf.borderWidth,
            range: BarSliderBands.borderWidth
        )
        .modifier(
            GreyOut(
                active: !shelf.wrappedValue.border,
                help: L(
                    "kiwishelf.border_width.border_off",
                    "Turn on \u{201C}%1$@\u{201D} to set its width.",
                    L("kiwishelf.border", "Border")
                )
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleBorderWidth
        )
    }
}
