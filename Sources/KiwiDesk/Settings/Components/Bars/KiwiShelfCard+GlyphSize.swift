import KiwiDeskCore
import SwiftUI

/// The KiwiShelf Style drawer's Glyph size group, above Font size
/// (#1713): automatic fills the thickness.
extension KiwiShelfCard {
    var glyphSizeGroup: some View {
        let thickness = shelf.thickness.wrappedValue
        return AutoGatedGroup(
            title: L("kiwishelf.glyph_size.auto", "Auto glyph size"),
            isOn: AutoSentinel.binding(
                shelf.glyphSize,
                restore: thickness
            ),
            caption: L(
                "kiwishelf.glyph_size.help",
                "How large app glyphs and counts draw on both bars. "
                    + "Automatic fills the thickness; a smaller size "
                    + "leaves room around each item, and KiwiShelf "
                    + "keeps its thickness. Never larger than the "
                    + "thickness. An automatic font size follows it."
            )
        ) {
            PtSlider(
                label: L("kiwishelf.glyph_size", "Glyph size"),
                value: shelf.glyphSize,
                range: BarSliderBands.glyphSize(thickness: thickness),
                autoAtZero: true,
                autoValue: thickness
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfStyle.children
                    .kiwishelfStyleGlyphSize
            )
        }
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleGlyphSizeAuto
        )
    }
}
