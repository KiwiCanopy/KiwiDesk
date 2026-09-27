import KiwiDeskCore
import SwiftUI

/// The KiwiShelf card's Item padding row, beside Thickness (#1682).
extension KiwiShelfCard {
    var itemPaddingRow: some View {
        PtSlider(
            label: L("kiwishelf.item_padding", "Item padding"),
            value: shelf.itemPadding,
            range: BarSliderBands.itemPadding,
            help: L(
                "kiwishelf.item_padding.help",
                "Room inside the thickness, between KiwiShelf's "
                    + "edge and each item's content. Icons, glyphs "
                    + "and an automatic font size shrink with it; "
                    + "the thickness stays."
            )
        )
    }
}
