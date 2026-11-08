import KiwiDeskCore
import SwiftUI

/// The line under a directional Maximize row (#3062): the share it
/// takes, read from the draft, and the Layout Defaults row that sets
/// it.
struct MaximizeShareCaption: View {
    @ObservedObject var model: SettingsModel
    let axis: MaximizeAxis

    var body: some View {
        let prose = Self.prose(
            axis: axis,
            share: SettingsValueReadout.percent(
                model.config.settings.maximize.share(for: axis)
            )
        )
        CrossReferenceRow(
            prose: prose,
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

    /// The sentence naming `share` of `axis`'s other side.
    static func prose(axis: MaximizeAxis, share: String) -> String {
        switch axis {
        case .height:
            return L(
                "shortcuts.maximize_height.share",
                "Uses %1$@ of the screen's width, set in %2$@.",
                share,
                CrossReferenceRow.linkSlot
            )
        case .width:
            return L(
                "shortcuts.maximize_width.share",
                "Uses %1$@ of the screen's height, set in %2$@.",
                share,
                CrossReferenceRow.linkSlot
            )
        }
    }
}
