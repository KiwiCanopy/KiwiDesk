import Foundation

/// Stamps every order of a window's chrome — its ring, its mark —
/// so a KiwiVision float veil can tell which sits topmost (#2103
/// ruling 3): chrome orders directly above its window, so of the
/// pieces ordered against it the earliest is on top. Nothing resets
/// on a raise; the watch's restack re-stamps every piece, which is
/// what keeps the stamps about the window's current stack.
@MainActor
enum ChromeOrderClock {
    private static var last: UInt64 = 0

    /// A stamp later than every one handed out before.
    static func tick() -> UInt64 {
        last += 1
        return last
    }
}
