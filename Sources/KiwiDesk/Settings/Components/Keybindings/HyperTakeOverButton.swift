import KiwiDeskCore
import SwiftUI

/// Offered under a refused Hyper key whose blocking remap is
/// exactly KiwiDesk's own entry (#2471): Core's `claimable` decides
/// the offer, and the alert says what the take-over costs.
struct HyperTakeOverButton: View {
    @ObservedObject var model: SettingsModel
    let foreign: HyperForeignRemap
    @State private var confirming = false

    var body: some View {
        Button(L("shortcuts.hyper_key.take_over", "Take Over")) {
            confirming = true
        }
        .settingsActionButton()
        .controlSize(.small)
        .padding(.leading, SettingsMetrics.shortcutIconSlot + 8)
        .alert(
            L(
                "shortcuts.hyper_key.take_over.title",
                "Take Over This Remap?"
            ),
            isPresented: $confirming
        ) {
            Button(
                L("shortcuts.hyper_key.take_over.cancel", "Cancel"),
                role: .cancel
            ) {}
            Button(
                L("shortcuts.hyper_key.take_over.confirm", "Take Over")
            ) {
                model.takeOverHyperRemap()
            }
        } message: {
            Text(Self.message(foreign))
        }
    }

    static func message(_ foreign: HyperForeignRemap) -> String {
        L(
            "shortcuts.hyper_key.take_over.message",
            "KiwiDesk will use this remap of %1$@ to %2$@ as Hyper "
                + "and remove it when it quits. An app that listens "
                + "for that key still hears it.",
            HyperKeyWords.name(foreign.source),
            HyperKeyWords.name(foreign.destination)
        )
    }
}
