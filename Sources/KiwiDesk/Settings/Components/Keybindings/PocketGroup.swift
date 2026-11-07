import KiwiDeskCore
import SwiftUI

/// The Pocket card (#2680): ⌃⌥P and ⌃⌥⇧P, then what the pocket
/// holds (#2678) and where its plate sits. The plate shows on every
/// window drag whatever the animation switch says, so no row greys.
struct PocketGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.pocketCard) {
            Group {
                ForEach(ShortcutsRowOrder.pocketAtRest, id: \.id) {
                    key in
                    KeybindingFamilyRows(
                        model: model,
                        bindings: $bindings,
                        key: key,
                        expander: expander
                    )
                }
            }
            // Aligns the trash-less rows with the per-app rows'
            // trash, as Open applications does (#2922).
            .environment(\.keybindingReservesTrashSlot, true)
            // Each app's own key (#2612).
            PocketAppRows(model: model, bindings: $bindings)
        }
    }

    /// The track's ends name where the position runs: left to
    /// right on a top or bottom edge, top to bottom on a side.
    static func ends(_ edge: AppBarEdge) -> (
        leading: String, trailing: String
    ) {
        edge.isHorizontal
            ? ("arrow.left.to.line", "arrow.right.to.line")
            : ("arrow.up.to.line", "arrow.down.to.line")
    }

    /// The position with the end it counts from, one sentence per
    /// orientation so a translator keeps the agreement.
    static func spokenPosition(_ readout: String, edge: AppBarEdge)
        -> String
    {
        edge.isHorizontal
            ? L(
                "pocket.position.spoken.horizontal",
                "%1$@ from the left",
                readout
            )
            : L(
                "pocket.position.spoken.vertical",
                "%1$@ from the top",
                readout
            )
    }
}
