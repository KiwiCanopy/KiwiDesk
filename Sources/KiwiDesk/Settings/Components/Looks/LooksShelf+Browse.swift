import AppKit
import KiwiDeskCore
import SwiftUI

/// Browse looks… (#1740 ▸ Browse): the gallery's site page in the
/// browser.
extension LooksShelf {
    var browseButton: some View {
        Button {
            NSWorkspace.shared.open(SupportLinks.looks)
        } label: {
            Label(
                L("looks.browse", "Browse looks…"),
                systemImage: "square.grid.2x2"
            )
        }
        .settingsActionButton()
        .controlSize(.small)
    }
}
