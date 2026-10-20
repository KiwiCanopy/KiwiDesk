import KiwiDeskCore
import SwiftUI

/// Offered under a refused Hyper key whose blocking remap is
/// exactly KiwiDesk's own entry (#2471): Core's `claimable` decides
/// the offer, and the alert says what the take-over costs. A
/// take-over that lands removes the button, so `onTakenOver`
/// states the focus destination (#816).
struct HyperTakeOverButton: View {
    @ObservedObject var model: SettingsModel
    let foreign: HyperForeignRemap
    let onTakenOver: () -> Void
    @State private var confirming = false

    var body: some View {
        Button(L("shortcuts.hyper_key.take_over", "Take Over…")) {
            confirming = true
        }
        .settingsActionButton()
        .accessibilityLabel(
            L(
                "shortcuts.hyper_key.take_over.ax",
                "Take Over the %1$@ Remap",
                HyperKeyWords.name(foreign.source)
            )
        )
        .alert(
            L(
                "shortcuts.hyper_key.take_over.title",
                "Take Over the %1$@ Remap?",
                HyperKeyWords.name(foreign.source)
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
                if model.hyperStatus == .on { onTakenOver() }
            }
            // The user already chose Take Over and the message says
            // what it does, so Return confirms (owner, 2026-10-20).
            .keyboardShortcut(.defaultAction)
        } message: {
            Text(Self.message(foreign))
        }
    }

    static func message(_ foreign: HyperForeignRemap) -> String {
        L(
            "shortcuts.hyper_key.take_over.message",
            "%1$@ → %2$@ is the remap KiwiDesk sets itself, so a "
                + "remapping app may have left it behind when it quit. "
                + "KiwiDesk will use it as Hyper and remove it when "
                + "KiwiDesk quits. If another app still listens for "
                + "%2$@, it also responds when you press %1$@.",
            HyperKeyWords.name(foreign.source),
            HyperKeyWords.name(foreign.destination)
        )
    }
}
