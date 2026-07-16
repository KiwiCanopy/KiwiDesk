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

/// Identity and display name of a running application, captured
/// once when KiwiDesk attaches to the app.
///
/// `bundleID` is the stable match key that app rules
/// (`float_rules`, `app_rules`) and the app launcher
/// (`pull_or_spawn`) target: canonical, locale-independent, and
/// unaffected by bundle renames — unlike the localized display
/// name, which is presentation, not identity. It is lower-cased
/// on the way in because LaunchServices treats bundle
/// identifiers case-insensitively, so a stored config value and
/// the live `NSRunningApplication.bundleIdentifier` compare in
/// one case. Nil for unbundled helper processes, which cannot be
/// targeted by a rule (accepted limitation — see
/// docs/design-decisions.md).
///
/// `name` is the localized display name, for the menu bar,
/// diagnostics, and logging only — never for matching.
public struct AppRef: Sendable, Equatable {
    public let bundleID: String?
    public let name: String

    public init(bundleID: String?, name: String) {
        self.bundleID = bundleID.map { $0.lowercased() }
        self.name = name
    }
}

/// A snapshot of one application window tracked by KiwiDesk.
///
/// This is pure state: it never talks to the Accessibility API.
/// The event loop keeps these snapshots up to date.
public struct ManagedWindow: Sendable, Equatable {
    public let id: WindowID
    public let pid: pid_t
    public var appName: String
    /// The owning app's bundle identifier — the key app rules
    /// match on (see `AppRef`). Nil for unbundled processes.
    public var appBundleID: String?
    public var title: String
    public var frame: CGRect
    public var isFloating: Bool
    /// A transient overlay — a launcher/panel that floats for a
    /// structural reason (accessory activation policy, non-standard
    /// panel subrole, or a raised CGWindow layer), NOT because a
    /// `float_rules` entry matched. Such windows (Spotlight,
    /// Raycast, Alfred) take focus momentarily and must not receive
    /// a KiwiDesk focus ring, unlike a user-floated standard window
    /// (#300). Classified once at track time (`EventLoop.track`).
    public var isTransientOverlay: Bool

    public init(
        id: WindowID,
        pid: pid_t,
        appName: String,
        appBundleID: String? = nil,
        title: String = "",
        frame: CGRect = .zero,
        isFloating: Bool = false,
        isTransientOverlay: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appBundleID = appBundleID
        self.title = title
        self.frame = frame
        self.isFloating = isFloating
        self.isTransientOverlay = isTransientOverlay
    }

    /// A copy carrying a different id, every other field preserved.
    /// `id` is a `let` (a window's identity is immutable), so a
    /// native-tab re-key (#308) — where the tracked `CGWindowID`
    /// changes as the active tab switches but the window is the
    /// same — must reconstruct the snapshot. Kept next to the field
    /// list so the mirror lives in one place; a `WindowManager`
    /// round-trip test guards it against a forgotten field.
    public func withID(_ newID: WindowID) -> ManagedWindow {
        ManagedWindow(
            id: newID,
            pid: pid,
            appName: appName,
            appBundleID: appBundleID,
            title: title,
            frame: frame,
            isFloating: isFloating,
            isTransientOverlay: isTransientOverlay
        )
    }
}
