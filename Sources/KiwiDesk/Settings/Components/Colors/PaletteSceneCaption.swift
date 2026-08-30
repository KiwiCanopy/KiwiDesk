import KiwiDeskCore
import SwiftUI

/// The one sentence describing the panel-scale palette scene
/// (`PaletteSceneThumbnail`, `PaletteSceneRoles.withheld`).
@MainActor
enum PaletteSceneCaption {
    static var panel: String {
        L(
            "colors.scene.caption",
            "Both bars with their active items, the focused and "
                + "unfocused rings with their state marks, and "
                + "the drag ghost beside its drop zone."
        )
    }
}
