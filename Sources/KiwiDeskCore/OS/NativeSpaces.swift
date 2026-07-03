import CoreGraphics
import Foundation

/// A native macOS Space (Mission Control desktop).
public struct NativeSpace: Sendable, Equatable {
    public let id: SkyLight.SpaceID
    public let displayUUID: String
    public let isCurrent: Bool
}

/// Detection of native macOS Spaces via SkyLight.
///
/// All queries return nil/empty when the private APIs are
/// unavailable; callers must treat that as "single space" and
/// rely on the Accessibility fallback.
public enum NativeSpaces {
    /// The currently active space, or nil without SkyLight.
    public static func activeSpaceID() -> SkyLight.SpaceID? {
        guard let cid = SkyLight.connection,
            let getActiveSpace = SkyLight.getActiveSpace
        else { return nil }
        let space = getActiveSpace(cid)
        return space != 0 ? space : nil
    }

    /// The current space of one display (by display UUID).
    public static func currentSpace(
        displayUUID: String
    ) -> SkyLight.SpaceID? {
        guard let cid = SkyLight.connection,
            let currentSpace = SkyLight.displayCurrentSpace
        else { return nil }
        let space = currentSpace(cid, displayUUID as CFString)
        return space != 0 ? space : nil
    }

    /// All spaces across all displays.
    public static func allSpaces() -> [NativeSpace] {
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
                result.append(
                    NativeSpace(
                        id: id,
                        displayUUID: uuid,
                        isCurrent: id == current
                    )
                )
            }
        }
        return result
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
        guard let createDisplayUUID,
            let uuid = createDisplayUUID(display.raw)?
                .takeRetainedValue()
        else { return nil }
        let string = CFUUIDCreateString(nil, uuid)
        return string as String?
    }
}
