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

/// How widely a window sticks across Spaces (#414/#445).
///
/// A sticky window is a real member of exactly one space (the
/// flat-array invariant) — stickiness only DERIVES its presence
/// elsewhere and exempts it from the inactive-space stash. The
/// scope decides *where* that presence extends:
///
/// - `.none`: an ordinary window, hidden with its home space.
/// - `.global`: every space of EVERY monitor (the original #414
///   sticky). Wears the `infinity` mark.
/// - `.display`: every space of ONE monitor — its home space's
///   display (#445). Follows to another monitor only via an
///   explicit cross-display `move_to_space`, which re-homes it.
///   Wears the `pin.fill` mark.
///
/// The home DISPLAY is not stored: it is derived from the home
/// space's display on demand, so a re-home needs no bookkeeping.
public enum StickyScope: String, Sendable, Equatable, CaseIterable {
    case none
    case global
    case display
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
    /// Sticky scope: present on every space of every monitor
    /// (`.global`) or of just its home monitor (`.display`),
    /// instead of hiding with its home space (#414/#445).
    /// Orthogonal to `isFloating` — a per-window-instance value
    /// set by `make_sticky` / `make_display_sticky` / the toggles,
    /// never by detection. The window remains a member of exactly
    /// one space (the flat-array invariant); stickiness only
    /// exempts it from the inactive-space stash and derives its
    /// presence elsewhere.
    public var stickyScope: StickyScope

    /// Whether the window is sticky in ANY scope — the predicate
    /// the many "sticky at all" read sites want (pile exemption,
    /// z-order, indicator set). Scope-specific behavior (stash
    /// exemption, traveler injection, move guard) reads
    /// `stickyScope` directly.
    public var isSticky: Bool { stickyScope != .none }
    /// A transient overlay — a launcher/panel that floats for a
    /// structural reason (accessory activation policy, non-standard
    /// panel subrole, or a raised CGWindow layer), NOT because a
    /// `float_rules` entry matched. Such windows (Spotlight,
    /// Raycast, Alfred) take focus momentarily and must not receive
    /// a KiwiDesk focus ring, unlike a user-floated standard window
    /// (#300). Classified once at track time (`EventLoop.track`).
    public var isTransientOverlay: Bool
    /// Native (green-button) fullscreen: the window owns a
    /// dedicated macOS Space but stays a member of its home
    /// Space (no `.windowDestroyed` fires). It fills the
    /// display, so a focus ring would show only at the rounded
    /// corners — never draw one (jankyborders skips fullscreen
    /// windows too). Snapshotted from `kAXFullScreenAttribute`
    /// at track time and refreshed on reconcile — pure state,
    /// no AX in the border path.
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
            stickyScope: stickyScope,
            isTransientOverlay: isTransientOverlay,
            isFullscreen: isFullscreen
        )
    }
}
