import KiwiDeskCore
import SwiftUI

/// The KiwiShelf Style drawer's Highlight width row (#1680).
extension KiwiShelfCard {
    var highlightWidthRow: some View {
        PtSlider(
            label: L("kiwishelf.highlight_width", "Highlight width"),
            value: shelf.highlightWidth,
            range: BarSliderBands.highlightWidth,
            help: L(
                "kiwishelf.highlight_width.help",
                "How heavy the mark on the current Space and the "
                    + "focused window draws — the outline, or "
                    + "the edge mark in proportion."
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleHighlightWidth
        )
    }
}
