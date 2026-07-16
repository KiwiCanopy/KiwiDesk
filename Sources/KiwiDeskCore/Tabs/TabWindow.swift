import CoreGraphics
import Foundation

/// The signals the native-tab reconciler needs about one window,
/// snapshotted so the matcher stays pure (no AX access). `frame` is
/// the group's on-screen frame, stable across a tab switch and the
/// key the matcher pairs on. `hasTabGroup` means an `AXTabGroup` is
/// (for an appearing window) or was (for a vanished one, from the
/// event loop's carrier set) present — a re-key needs it on only one
/// side, since an app like Ghostty exposes the group only at 2+ tabs.
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
