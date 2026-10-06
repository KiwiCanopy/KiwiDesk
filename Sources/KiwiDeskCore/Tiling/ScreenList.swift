import AppKit

/// The connected screens, read through one door so a test core
/// can memoize the WindowServer round trip (#1894). Tiling reads
/// them only here (`ScreenListSeamTests`).
@MainActor
enum ScreenList {
    /// `NSScreen.screens`.
    static var all: [NSScreen] {
        #if DEBUG
            if let override { return override() }
        #endif
        return NSScreen.screens
    }

    /// `NSScreen.main`, else the first screen; a test core's list
    /// answers its first.
    static var mainOrFirst: NSScreen? {
        #if DEBUG
            if let override { return override().first }
        #endif
        return NSScreen.main ?? NSScreen.screens.first
    }

    #if DEBUG
        /// Test seam over both reads; nil reads the machine.
        static var override: (() -> [NSScreen])?
    #endif
}
