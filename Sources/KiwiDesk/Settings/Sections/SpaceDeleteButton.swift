import KiwiDeskCore
import SwiftUI

/// A Space row's trash, in the trailing danger slot (#205): the
/// Spaces page's rows and Simple's draw it (#2737). Its caller asks
/// first when the Space carries overrides
/// (`GuiConfig.carriesOverrides`, `SpaceDeleteWording`).
struct SpaceDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .iconButtonAffordance(
            L("spaces.delete.help", "Delete Space")
        )
    }
}
