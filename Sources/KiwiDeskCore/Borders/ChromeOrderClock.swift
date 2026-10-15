import Foundation

/// Stamps every order of a window's chrome — its ring, its mark —
/// so a KiwiVision float veil can tell which sits topmost (#2103
/// ruling 3): chrome orders directly above its window, so the
/// piece ordered EARLIEST since the window last rose is on top.
@MainActor
enum ChromeOrderClock {
    private static var last: UInt64 = 0

    /// A stamp later than every one handed out before.
    static func tick() -> UInt64 {
        last += 1
        return last
    }
}
