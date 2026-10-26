import CoreGraphics

/// One window's WindowServer level, the `kCGWindowLayer` the public
/// window list reports (#2531). Unlike that list, the read does not
/// first wait for this process's pending window updates while
/// holding the connection lock, so an off-main read cannot stall a
/// main-actor commit behind a slow app's held transaction.
extension SkyLight {
    typealias GetWindowLevelFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            UnsafeMutablePointer<Int32>
        ) -> CGError

    static let getWindowLevelSymbol = symbol(
        "SLSGetWindowLevel",
        as: GetWindowLevelFn.self
    )

    /// Whether `windowLevel` can answer at all.
    static var readsWindowLevel: Bool {
        getWindowLevelSymbol.function != nil && connection != nil
    }

    /// `wid`'s level, or nil where the server knows no such window.
    static func windowLevel(_ wid: CGWindowID) -> Int? {
        guard let connection,
            let getLevel = getWindowLevelSymbol.function
        else { return nil }
        var level: Int32 = 0
        guard getLevel(connection, wid, &level) == .success
        else { return nil }
        return Int(level)
    }
}
