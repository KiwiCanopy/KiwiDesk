import Foundation

/// The pocket's own refusal sentence (#2446, #96): drawn by Core
/// on the window, so it is localized here. The float half is
/// `AutoFloatReason.pocket`'s, which the bar menu reads too.
enum PocketRefusal {
    @MainActor
    static var stickySentence: String {
        L("pocket.refusal.sticky", "Pocket windows are always sticky")
    }
}
