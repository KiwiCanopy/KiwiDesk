import CoreGraphics
import Foundation

/// Stable identifier of a managed window.
///
/// Wraps the system `CGWindowID` so the rest of the codebase never
/// deals with raw integers.
public struct WindowID: Hashable, Sendable, Codable,
    CustomStringConvertible
{
    public let raw: UInt32

    public init(_ raw: UInt32) {
        self.raw = raw
    }

    public var description: String { "window#\(raw)" }
}

/// A snapshot of one application window tracked by KiwiDesk.
///
/// This is pure state: it never talks to the Accessibility API.
/// The event loop keeps these snapshots up to date.
public struct ManagedWindow: Sendable, Equatable {
    public let id: WindowID
    public let pid: pid_t
    public var appName: String
    public var title: String
    public var frame: CGRect
    public var isFloating: Bool

    public init(
        id: WindowID,
        pid: pid_t,
        appName: String,
        title: String = "",
        frame: CGRect = .zero,
        isFloating: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.title = title
        self.frame = frame
        self.isFloating = isFloating
    }
}
