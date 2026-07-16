import CoreGraphics
import Foundation

/// The signals the native-tab reconciler needs about one window,
/// snapshotted so the matcher stays pure (no AX access). A window is
/// eligible to take part in a tab-group re-key only when it carries
/// an `AXTabGroup` (`hasTabGroup`); `frame` is the group's on-screen
/// frame, which is stable across a tab switch and is the key the
/// matcher pairs on.
///
/// Native tabs (Finder, Terminal, Ghostty) are separate `NSWindow`s
/// sharing one on-screen frame, only the active one visible to AX at
/// a time, each with its own `CGWindowID` (see issue #308). A switch
/// therefore surfaces as one `TabWindow` vanishing and another
/// appearing at the same `frame`.
public struct TabWindow: Equatable, Sendable {
    public let id: WindowID
    public let frame: CGRect
    public let hasTabGroup: Bool

    public init(id: WindowID, frame: CGRect, hasTabGroup: Bool) {
        self.id = id
        self.frame = frame
        self.hasTabGroup = hasTabGroup
    }
}
