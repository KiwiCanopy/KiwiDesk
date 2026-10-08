import AppKit

/// The connected screens, read through one door so a test core
/// can memoize the WindowServer round trip (#1894) and every
/// Core reader agrees on which screen is main. Core reads them
/// only here (`ScreenListSeamTests`).
@MainActor
enum ScreenList {
    /// `NSScreen.screens`.
    static var all: [NSScreen] {
        #if DEBUG
            if let override { return override() }
        #endif
        return NSScreen.screens
    }

    /// `NSScreen.main`; a test core's list answers its first.
    static var main: NSScreen? {
        #if DEBUG
            if let override { return override().first }
        #endif
        return NSScreen.main
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
        /// Test seam over every read; nil reads the machine.
        static var override: (() -> [NSScreen])?
    #endif
}
