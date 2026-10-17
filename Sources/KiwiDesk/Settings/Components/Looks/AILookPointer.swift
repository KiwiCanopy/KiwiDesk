import KiwiDeskCore
import SwiftUI

/// The Looks page's pointer to the AI page (#1685 ▸ Ruling 6b):
/// the user's own AI app can make a new look through the `looks`
/// tool. Drawn only where the AI page is offered — it is
/// withdrawn while a stored profile is edited, and a link to a
/// page that cannot open is no link.
struct AILookPointer: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        if Self.isDrawn(
            editingStoredProfile: model.editingStoredProfile
        ) {
            CrossReferenceRow(
                prose: Self.prose,
                linkTitle: SettingsDestination.ai.title,
                destination: .ai
            )
        }
    }

    static func isDrawn(editingStoredProfile: Bool) -> Bool {
        SettingsDestination.ai.isReachable(
            editingStoredProfile: editingStoredProfile
        )
    }

    static var prose: String {
        L(
            "looks.ai.pointer",
            "Your AI can make you a new look — even one "
                + "matched to a screenshot of your wallpaper. Start "
                + "on the %1$@ page.",
            CrossReferenceRow.linkSlot
        )
    }
}
