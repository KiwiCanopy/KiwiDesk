import CoreGraphics

/// One window's on-screen flag, the `kCGWindowIsOnscreen` the public
/// window list reports, read without that list's wait on this
/// process's pending window updates (#2531, #2634). Probed on macOS
/// 27.0.1 against the flag on every window of two Desktops and
/// through held and cancelled swipes: `SLSWindowIsVisible` matched
/// it wherever `SLSWindowIsOrderedIn` reads true. Ordered in alone
/// is not the flag: a window on a Desktop no display shows reads
/// ordered in. A window ordered out (minimized, hidden, closing) is
/// left to the public read, whose missing entry the gate abstains on.
extension SkyLight {
    typealias WindowFlagFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            UnsafeMutablePointer<UInt8>
        ) -> CGError

    static let windowIsOrderedInSymbol = symbol(
        "SLSWindowIsOrderedIn",
        as: WindowFlagFn.self
    )
    static let windowIsVisibleSymbol = symbol(
        "SLSWindowIsVisible",
        as: WindowFlagFn.self
    )

    /// Whether `wid` is ordered in, or nil where unanswered.
    static func windowOrderedIn(_ wid: CGWindowID) -> Bool? {
        flag(windowIsOrderedInSymbol.function, wid)
    }

    /// Whether `wid` is visible, or nil where unanswered.
    static func windowVisible(_ wid: CGWindowID) -> Bool? {
        flag(windowIsVisibleSymbol.function, wid)
    }

    /// `wid`'s on-screen flag where SkyLight answers it: nil for a
    /// window ordered out, unknown, or a host without the symbols.
    static func windowOnScreen(_ wid: CGWindowID) -> Bool? {
        guard windowOrderedIn(wid) == true else { return nil }
        return windowVisible(wid)
    }

    private static func flag(
        _ read: WindowFlagFn?,
        _ wid: CGWindowID
    ) -> Bool? {
        guard let connection, let read else { return nil }
        var value: UInt8 = 0
        guard read(connection, wid, &value) == .success
        else { return nil }
        return value != 0
    }
}
