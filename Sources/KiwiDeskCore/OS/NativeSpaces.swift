import CoreGraphics
import Foundation

/// A native macOS Space (Mission Control desktop).
public struct NativeSpace: Sendable, Equatable {
    public let id: SkyLight.SpaceID
    public let displayUUID: String
    public let isCurrent: Bool
    /// False for fullscreen-app and system spaces, which
    /// Mission Control does not count as desktops.
    public let isUser: Bool

    public init(
        id: SkyLight.SpaceID,
        displayUUID: String,
        isCurrent: Bool,
        isUser: Bool = true
    ) {
        self.id = id
        self.displayUUID = displayUUID
        self.isCurrent = isCurrent
        self.isUser = isUser
    }
}

/// Detection of native macOS Spaces via SkyLight.
///
/// All queries return nil/empty when the private APIs are
/// unavailable; callers must treat that as "single space" and
/// rely on the Accessibility fallback.
public enum NativeSpaces {
    /// The currently active space, or nil without SkyLight.
    public static func activeSpaceID() -> SkyLight.SpaceID? {
        #if DEBUG
            if let override = activeSpaceIDOverride {
                return override
            }
        #endif
        guard let cid = SkyLight.connection,
            let getActiveSpace = SkyLight.getActiveSpace
        else { return nil }
        let space = getActiveSpace(cid)
        return space != 0 ? space : nil
    }

    /// Current space of display by UUID
    /// (`SLSManagedDisplayGetCurrentSpace`, #1023, 2026-08-26).
    public static func currentSpace(
        displayUUID: String
    ) -> SkyLight.SpaceID? {
        #if DEBUG
            if let override = currentSpaceOverride {
                return override(displayUUID)
            }
        #endif
        guard let cid = SkyLight.connection,
            let currentSpace = SkyLight.displayCurrentSpace
        else { return nil }
        let space = currentSpace(cid, displayUUID as CFString)
        return space != 0 ? space : nil
    }

    /// All spaces across all displays.
    public static func allSpaces() -> [NativeSpace] {
        #if DEBUG
            if let override = spacesOverride {
                return override
            }
        #endif
        guard let cid = SkyLight.connection,
            let copySpaces = SkyLight.copyManagedDisplaySpaces,
            let unmanaged = copySpaces(cid)
        else { return [] }
        let array = unmanaged.takeRetainedValue()
        guard let displays = array as? [[String: Any]] else {
            return []
        }
        var result: [NativeSpace] = []
        for display in displays {
            let uuid =
                display["Display Identifier"] as? String ?? ""
            let current =
                (display["Current Space"] as? [String: Any])?[
                    "id64"
                ] as? UInt64
            let spaces =
                display["Spaces"] as? [[String: Any]] ?? []
            for space in spaces {
                guard let id = space["id64"] as? UInt64 else {
                    continue
                }
                let type = space["type"] as? Int ?? 0
                result.append(
                    NativeSpace(
                        id: id,
                        displayUUID: uuid,
                        isCurrent: id == current,
                        isUser: type == 0
                    )
                )
            }
        }
        return result
    }

    /// 1-based Mission Control number of space.
    public static func number(
        of id: SkyLight.SpaceID,
        in spaces: [NativeSpace]
    ) -> Int? {
        spaces
            .filter(\.isUser)
            .firstIndex { $0.id == id }
            .map { $0 + 1 }
    }

    /// Whether space is a regular user desktop (#670).
    public static func isUserSpace(
        _ id: SkyLight.SpaceID,
        in spaces: [NativeSpace]
    ) -> Bool {
        spaces.first { $0.id == id }?.isUser ?? true
    }

    /// Whether active native space is a user desktop (`isUser`, #670).
    public static func activeSpaceIsUser() -> Bool {
        #if DEBUG
            if let override = activeSpaceIsUserOverride {
                return override
            }
        #endif
        guard let id = activeSpaceID() else { return true }
        return isUserSpace(id, in: allSpaces())
    }

    /// Whether space on display is a user desktop.
    public static func currentSpaceIsUser(
        display: DisplayID
    ) -> Bool {
        #if DEBUG
            if let override = currentSpaceIsUserOverride {
                return override(display)
            }
        #endif
        guard let uuid = displayUUID(for: display),
            let id = currentSpace(displayUUID: uuid)
        else { return true }
        return isUserSpace(id, in: allSpaces())
    }

    #if DEBUG
        /// Pins the Desktop number for BOTH readers — outside a
        /// topology fixture they are the same number, and pinning
        /// one but not the other reads the host's WindowServer
        /// through the unpinned one (#523). A test needing them
        /// to DIVERGE pins the topology instead: `spacesOverride`,
        /// `mainDisplayUUIDOverride` AND `activeSpaceIDOverride`
        /// (review 2026-08-18).
        public static nonisolated(unsafe) var activeDesktopNumberOverride: Int?
        public static nonisolated(unsafe) var activeSpaceIsUserOverride: Bool?
        /// Override for per-display pointer verification (#1023).
        public static nonisolated(unsafe) var currentSpaceOverride:
            ((String) -> SkyLight.SpaceID?)?
        public static nonisolated(unsafe) var currentSpaceIsUserOverride:
            ((DisplayID) -> Bool)?
        public static nonisolated(unsafe) var spacesOverride: [NativeSpace]?
        public static nonisolated(unsafe) var activeSpaceIDOverride:
            SkyLight.SpaceID?
        public static nonisolated(unsafe) var mainDisplayUUIDOverride: String?
        public static nonisolated(unsafe) var displayUUIDOverride:
            ((DisplayID) -> String?)?
    #endif

    /// The native Space the WindowServer hosts `window` on — the
    /// compositor's answer, independent of any notification's
    /// timing (#1207). Nil without SkyLight. Production reads it
    /// through `DesktopMemory.readWindowSpace` alone (#1146,
    /// `DesktopCensusSeamTests`), which a test pins per core.
    public static func nativeSpace(
        of window: WindowID
    ) -> SkyLight.SpaceID? {
        guard let connection = SkyLight.connection else { return nil }
        return SkyLight.windowSpace(
            window.raw,
            connection: connection
        )
    }

    /// Mission Control number of active space (#888).
    public static func activeSpaceNumber() -> Int? {
        #if DEBUG
            if let override = activeDesktopNumberOverride {
                return override
            }
        #endif
        guard let id = activeSpaceID() else { return nil }
        return number(of: id, in: allSpaces())
    }

    /// C signature of CGDisplayCreateUUIDFromDisplayID, which
    /// current SDKs no longer expose to Swift directly.
    private typealias DisplayUUIDFn =
        @convention(c) (UInt32) -> Unmanaged<CFUUID>?

    private static let createDisplayUUID: DisplayUUIDFn? = {
        // CoreGraphics is already loaded; look the symbol up
        // in the global namespace.
        guard
            let sym = dlsym(
                dlopen(nil, RTLD_LAZY),
                "CGDisplayCreateUUIDFromDisplayID"
            )
        else { return nil }
        return unsafeBitCast(sym, to: DisplayUUIDFn.self)
    }()

    /// Stable UUID string for a display, used by SkyLight APIs.
    public static func displayUUID(
        for display: DisplayID
    ) -> String? {
        #if DEBUG
            if let override = displayUUIDOverride {
                return override(display)
            }
        #endif
        guard let createDisplayUUID,
            let uuid = createDisplayUUID(display.raw)?
                .takeRetainedValue()
        else { return nil }
        let string = CFUUIDCreateString(nil, uuid)
        return string as String?
    }
}
