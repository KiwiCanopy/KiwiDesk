import Foundation

/// The pocket's own refusal sentences (#2446, #96): drawn by Core
/// on the window, so it is localized here. The float half is
/// `AutoFloatReason.pocket`'s, which the bar menu reads too.
enum PocketRefusal {
    @MainActor
    static var stickySentence: String {
        L("pocket.refusal.sticky", "Pocket windows are always sticky")
    }

    /// A general-list verb on a window its app's key owns (#2612
    /// ▸ 1), naming that key as the GUI renders it live; nil where
    /// no GUI reads one.
    @MainActor
    static func keyedSentence(chord: String?) -> String {
        guard let chord else {
            return L(
                "pocket.refusal.keyed_unnamed",
                "This window has a Pocket key of its own"
            )
        }
        return L("pocket.refusal.keyed", "Its Pocket key is %1$@", chord)
    }

    /// `toggle_pocket_window` on a second window (#2675), drawn
    /// beside `PocketMark.takenName`.
    @MainActor
    static var markedElsewhereSentence: String {
        L("pocket.refusal.marked_elsewhere", "Pocket is already taken")
    }
}
