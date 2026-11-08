import KiwiDeskCore
import SwiftUI

/// The line under a directional Maximize row (#3062): its share
/// depends on the screen's shape, set in Layout Defaults ▸ Maximize.
struct MaximizeShareCaption: View {
    let axis: MaximizeAxis

    var body: some View {
        CrossReferenceRow(
            prose: Self.prose(axis: axis),
            linkTitle: L(
                "shortcuts.maximize.xref_link",
                "%1$@ ▸ %2$@",
                SettingsDestination.layoutDefaults.title,
                SettingsCatalog.layoutDefaults.maximizeCard.text
            ),
            destination: .layoutDefaults,
            row: row
        )
    }

    private var row: SettingsControl {
        switch axis {
        case .height: SettingsCatalog.layoutDefaults.maximizeHeightShare
        case .width: SettingsCatalog.layoutDefaults.maximizeWidthShare
        }
    }

    /// The sentence for `axis`'s other side.
    static func prose(axis: MaximizeAxis) -> String {
        switch axis {
        case .height:
            return L(
                "shortcuts.maximize_height.by_shape",
                "Its width depends on the screen's shape, set in %1$@.",
                CrossReferenceRow.linkSlot
            )
        case .width:
            return L(
                "shortcuts.maximize_width.by_shape",
                "Its height depends on the screen's shape, set in %1$@.",
                CrossReferenceRow.linkSlot
            )
        }
    }
}
