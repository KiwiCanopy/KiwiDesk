import CoreGraphics
import Foundation

/// Stable identifier of a managed window wrapping `CGWindowID`.
public struct WindowID: Hashable, Sendable, Codable,
    CustomStringConvertible
{
    public let raw: UInt32

    public init(_ raw: UInt32) {
        self.raw = raw
    }

    public var description: String { "window#\(raw)" }
}

/// Running application identity and localized display name.
public struct AppRef: Sendable, Equatable {
    public let bundleID: String?
    public let name: String

    public init(bundleID: String?, name: String) {
        self.bundleID = bundleID.map { $0.lowercased() }
        self.name = name
    }
}

/// Stickiness scope across Spaces (#414, #445).
public enum StickyScope: String, Sendable, Equatable, CaseIterable {
    case none
    case global
    case display
}

/// Pure state snapshot of a window tracked by KiwiDesk.
public struct ManagedWindow: Sendable, Equatable {
    public let id: WindowID
    public let pid: pid_t
    public var appName: String
    /// Owning app bundle ID for rule matching.
    public var appBundleID: String?
    public var title: String
    public var frame: CGRect
    public var isFloating: Bool
    /// Stickiness across spaces (#414, #445).
    public var stickyScope: StickyScope

    /// True if window is sticky in any scope.
    public var isSticky: Bool { stickyScope != .none }
    /// Transient launcher or accessory panel without focus ring (#300).
    public var isTransientOverlay: Bool
    /// Native fullscreen state (`kAXFullScreenAttribute`).
    public var isFullscreen: Bool

    public init(
        id: WindowID,
        pid: pid_t,
        appName: String,
        appBundleID: String? = nil,
        title: String = "",
        frame: CGRect = .zero,
        isFloating: Bool = false,
        stickyScope: StickyScope = .none,
        isTransientOverlay: Bool = false,
        isFullscreen: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appBundleID = appBundleID
        self.title = title
        self.frame = frame
        self.isFloating = isFloating
        self.stickyScope = stickyScope
        self.isTransientOverlay = isTransientOverlay
        self.isFullscreen = isFullscreen
    }

    /// Reconstructs snapshot with a new `WindowID` for native tab switches
    /// (#308).
    public func withID(_ newID: WindowID) -> ManagedWindow {
        ManagedWindow(
            id: newID,
            pid: pid,
            appName: appName,
            appBundleID: appBundleID,
            title: title,
            frame: frame,
            isFloating: isFloating,
            stickyScope: stickyScope,
            isTransientOverlay: isTransientOverlay,
            isFullscreen: isFullscreen
        )
    }
}
