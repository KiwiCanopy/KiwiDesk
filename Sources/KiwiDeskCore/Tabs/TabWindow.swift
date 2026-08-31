import CoreGraphics
import Foundation

/// Window snapshot for pure native-tab reconciliation (#308).
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
