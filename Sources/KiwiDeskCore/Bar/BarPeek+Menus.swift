import AppKit

/// The peek's menu tracking (#1946, #761): any menu opening closes
/// the peek, which would otherwise stand beside it, and none opens
/// while one tracks; the window a bar menu opens on — a right-press
/// on a shelf panel, "N more" on the peek's anchor — holds its
/// shelf until the menu's tracking ends. Moved only through its
/// begin and end, which the menus' notifications balance.
struct BarMenuTracking {
    private var count = 0
    /// Its identity, never the window, which the peek does not own.
    private var anchor: ObjectIdentifier?

    var isTracking: Bool { count > 0 }

    func opened(on window: NSWindow) -> Bool {
        anchor == ObjectIdentifier(window)
    }

    mutating func began() { count += 1 }

    mutating func ended() {
        count = max(count - 1, 0)
        if count == 0 { anchor = nil }
    }

    mutating func note(_ window: NSWindow?) {
        anchor = window.map(ObjectIdentifier.init)
    }
}
