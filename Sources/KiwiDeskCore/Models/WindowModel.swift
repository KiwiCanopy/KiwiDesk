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
/// `bundleID` is lower-cased on the way in: LaunchServices treats
/// bundle identifiers case-insensitively, so a stored config
/// value and the live `NSRunningApplication` value must compare
/// in one case. `name` is presentation only — never matching.
public struct AppRef: Sendable, Equatable {
    public let bundleID: String?
    public let name: String

    public init(bundleID: String?, name: String) {
        self.bundleID = bundleID.map { $0.lowercased() }
        self.name = name
    }

    /// How a user's app list names this app (#2103 ruling 26): its
    /// bundle id, or its process name where it has none, lowercased.
    public var listKey: String { bundleID ?? name.lowercased() }
}

/// Stickiness scope across Spaces (#414, #445).
public enum StickyScope: String, Sendable, Equatable, CaseIterable,
    Codable
{
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
    /// WindowServer layer above the normal one at adoption — a
    /// popup menu, a reaction bar (#1602).
    public var isRaisedLayer: Bool
    /// Close, minimize, zoom or full-screen button present at
    /// adoption; nil where the read did not answer.
    public var hasTitlebarButton: Bool?
    /// Native fullscreen state (`kAXFullScreenAttribute`).
    public var isFullscreen: Bool
    /// Carries KiwiDesk's own tiling mark (`OwnWindowTiling`), so
    /// its reopen identity is the mark, never its area-named title
    /// (#2059).
    public var carriesOwnMark: Bool
    /// The AX subrole, read at adoption and refreshed by
    /// `.windowSubroleChanged`; empty where the read failed, nil
    /// before any. A titled window reads `AXStandardWindow`
    /// whatever its frame, so it never presents (#1788).
    public var subrole: String?

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
        isRaisedLayer: Bool = false,
        hasTitlebarButton: Bool? = nil,
        isFullscreen: Bool = false,
        carriesOwnMark: Bool = false,
        subrole: String? = nil
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
        self.isRaisedLayer = isRaisedLayer
        self.hasTitlebarButton = hasTitlebarButton
        self.isFullscreen = isFullscreen
        self.carriesOwnMark = carriesOwnMark
        self.subrole = subrole
    }

    /// Reconstructs the snapshot with a new `WindowID` for native
    /// tab switches (#308) — kept beside the field list so the
    /// mirror lives in one place; a `WindowManager` round-trip
    /// test guards a forgotten field.
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
            isRaisedLayer: isRaisedLayer,
            hasTitlebarButton: hasTitlebarButton,
            isFullscreen: isFullscreen,
            carriesOwnMark: carriesOwnMark,
            subrole: subrole
        )
    }
}

/// A window the compositor hosts on a Desktop nobody shows
/// (#1146): the facts the departure fold erased, kept beside the
/// pure state so Open-or-Focus and the gone classifier can name
/// it — no bar draws it (#1228). Its KiwiDesk space and rank stay in
/// `rememberedSpaces` / `departedSlots` (#1207) — an entry with
/// none there is UNFILED: known, drawn nowhere.
public struct AwayWindow: Sendable, Equatable {
    public let id: WindowID
    public let pid: pid_t
    public let appName: String
    public let appBundleID: String?
    /// Its title when it left; empty for a boot-seeded entry,
    /// which no AX read named (#1875 lists it by app name).
    public let title: String
    /// The native Space hosting it at the last reading.
    public var nativeSpace: SkyLight.SpaceID
    /// Up on that Desktop at the last reading; a window parked
    /// (minimized) while away is not reached, as one minimized
    /// here is not.
    public var isUp: Bool

    public init(
        id: WindowID,
        pid: pid_t,
        appName: String,
        appBundleID: String?,
        title: String = "",
        nativeSpace: SkyLight.SpaceID,
        isUp: Bool = true
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appBundleID = appBundleID
        self.title = title
        self.nativeSpace = nativeSpace
        self.isUp = isUp
    }

    /// The same entry under a new id (#308 re-key).
    public func withID(_ newID: WindowID) -> AwayWindow {
        AwayWindow(
            id: newID,
            pid: pid,
            appName: appName,
            appBundleID: appBundleID,
            title: title,
            nativeSpace: nativeSpace,
            isUp: isUp
        )
    }
}
