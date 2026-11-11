import Foundation
import KiwiDeskCore

/// What swells for a beat at a Desktops refusal (#3170): the window
/// a carry block refuses, otherwise the line.
enum DesktopsSwell: Equatable {
    case window(WindowID)
    case place(DesktopsPlace)
}

/// The Desktops side's refusals, shown in the footer (#3170): the
/// reason stays until the next key, click or selection change, with
/// no timer, and the refused thing swells as a refused Windows row
/// does. Sound and VoiceOver stay on `onRefuse`.
extension JumpModel {
    func refuseDesktops(_ text: String, swelling swell: DesktopsSwell?) {
        desktopsRefusal = text
        desktopsSwell = swell
        onRefuse(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            [weak self] in
            if self?.desktopsSwell == swell { self?.desktopsSwell = nil }
        }
    }

    /// Swells the line a refusal of no window names.
    func refuseDesktops(_ text: String) {
        refuseDesktops(text, swelling: desktops?.place.map { .place($0) })
    }

    /// Ends a shown refusal; the next input calls it first.
    func endDesktopsRefusal() {
        if desktopsRefusal != nil { desktopsRefusal = nil }
    }
}
