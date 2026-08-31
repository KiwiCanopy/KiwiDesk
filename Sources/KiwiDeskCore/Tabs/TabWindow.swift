import CoreGraphics
import Foundation

/// Window snapshot for pure native-tab reconciliation (#308).
/// Native tabs are separate NSWindows sharing one on-screen
/// frame, each with its own CGWindowID, only the active one
/// visible to AX — a switch surfaces as one TabWindow
/// vanishing and another appearing at the same `frame`, the
/// key the matcher pairs on. `hasTabGroup` means an AXTabGroup
/// is (appearing) or was (vanished) present — needed on only
/// ONE side, since e.g. Ghostty exposes the group only at 2+
/// tabs.
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
