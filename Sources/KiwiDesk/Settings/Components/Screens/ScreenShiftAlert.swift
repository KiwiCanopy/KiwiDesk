import KiwiDeskCore
import SwiftUI

/// The boxed-in offer's one question (#2756), hosted at the shell
/// so the Screens row and both checklists ask the same alert:
/// Shift, Keep as Is, Cancel. Cancel remembers nothing, so an
/// accidental open is no decline.
struct ScreenShiftAlert: ViewModifier {
    @ObservedObject var model: SettingsModel

    func body(content: Content) -> some View {
        let state = model.screenShift
        let offer = state.asking
        content.alert(
            offer.map { ScreenShiftText.alertTitle($0, in: state) } ?? "",
            isPresented: Binding(
                get: { model.screenShift.asking != nil },
                set: { if !$0 { model.screenShift.asking = nil } }
            ),
            presenting: offer
        ) { offer in
            Button(ScreenShiftText.shiftAction) {
                model.applyScreenShift(offer)
            }
            .keyboardShortcut(.defaultAction)
            Button(ScreenShiftText.keepAction) {
                model.keepArrangement()
            }
            Button(L("screens.shift.alert.cancel", "Cancel"), role: .cancel) {}
        } message: { offer in
            Text(ScreenShiftText.alertMessage(offer, in: state))
        }
    }
}

extension View {
    /// Hosts the boxed-in offer's alert (`ScreenShiftAlert`).
    func screenShiftAlert(_ model: SettingsModel) -> some View {
        modifier(ScreenShiftAlert(model: model))
    }
}
