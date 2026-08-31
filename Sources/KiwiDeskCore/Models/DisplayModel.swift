import CoreGraphics
import Foundation

/// Identifier of a physical display (wraps `CGDirectDisplayID`).
public struct DisplayID: Hashable, Sendable, Codable,
    CustomStringConvertible
{
    public let raw: UInt32

    public init(_ raw: UInt32) {
        self.raw = raw
    }

    public var description: String { "display#\(raw)" }
}

/// Snapshot of a connected monitor with hardware fingerprint.
public struct Display: Sendable, Equatable {
    public let id: DisplayID
    public var name: String
    /// Frame in AppKit global coordinates, where y grows UP: the
    /// screen physically above another has the LARGER `minY`, so
    /// an ascending sort reads bottom-to-top — two sorters got
    /// this wrong already (#752; `DeskOrder` negates y for this).
    public var frame: CGRect
    /// Usable area (frame minus menu bar and Dock).
    public var visibleFrame: CGRect

    public init(
        id: DisplayID,
        name: String,
        frame: CGRect,
        visibleFrame: CGRect? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame ?? frame
    }

    /// Stable identity string based on name and resolution.
    public var fingerprint: String {
        let w = Int(frame.width)
        let h = Int(frame.height)
        return "\(name):\(w)x\(h)"
    }
}
