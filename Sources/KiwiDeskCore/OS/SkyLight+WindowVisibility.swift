import CoreGraphics

/// One window's `kCGWindowIsOnscreen`, read without the public
/// list's wait on this process's pending window updates (#2531).
/// The canonical home of why it takes two reads (#2634, probed on
/// macOS 27.0.1): ordered in alone reads true for a window on a
/// Desktop no display shows, and visible reads false for a window
/// ordered out (minimized, hidden) where the public read has no
/// entry at all. So visible answers only for a window ordered in;
/// every other window is nil, left to the public read.
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

    /// Whether `windowOnScreen` can answer at all.
    static var readsWindowOnScreen: Bool {
        windowIsOrderedInSymbol.function != nil
            && windowIsVisibleSymbol.function != nil
            && connection != nil
    }

    /// Whether `wid` is ordered in, or nil where unanswered.
    static func windowOrderedIn(_ wid: CGWindowID) -> Bool? {
        flag(windowIsOrderedInSymbol.function, wid)
    }

    /// Whether `wid` is visible, or nil where unanswered.
    static func windowVisible(_ wid: CGWindowID) -> Bool? {
        flag(windowIsVisibleSymbol.function, wid)
    }

    /// `wid`'s on-screen flag where SkyLight answers it.
    static func windowOnScreen(_ wid: CGWindowID) -> Bool? {
        onScreen(
            orderedIn: windowOrderedIn(wid),
            visible: { windowVisible(wid) }
        )
    }

    /// The two reads combined; `visible` is asked only for a window
    /// ordered in.
    static func onScreen(
        orderedIn: Bool?,
        visible: () -> Bool?
    ) -> Bool? {
        guard orderedIn == true else { return nil }
        return visible()
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
