import CoreFoundation
import CoreGraphics
import Foundation

/// Runtime-only SkyLight reads the focus border and the Desktop
/// gates share: a window's WindowServer bounds and the Spaces
/// hosting it. Every symbol is optional; nil is "cannot read".
extension SkyLight {
    typealias GetWindowBoundsFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            UnsafeMutablePointer<CGRect>
        ) -> CGError
    typealias CopySpacesForWindowsFn =
        @convention(c) (
            ConnectionID, UInt32, CFArray
        ) -> Unmanaged<CFArray>?

    static let getWindowBounds: GetWindowBoundsFn? = symbol(
        "SLSGetWindowBounds",
        as: GetWindowBoundsFn.self
    )
    static let copySpacesForWindows: CopySpacesForWindowsFn? =
        symbol(
            "SLSCopySpacesForWindows",
            as: CopySpacesForWindowsFn.self
        )

    /// `SLSCopySpacesForWindows` selector for all space types.
    private static let allSpacesSelector: UInt32 = 0x7

    /// Queries WindowServer for space hosting target window (`SpaceID`).
    static func windowSpace(
        _ target: CGWindowID,
        connection: ConnectionID
    ) -> SpaceID? {
        windowSpaces(target, connection: connection)?.first
    }

    /// EVERY Space hosting `target` — several for an all-Desktops
    /// window (#1410). Nil when the read cannot be made, empty
    /// for a window hosted nowhere (closed, os-private-apis.md).
    static func windowSpaces(
        _ target: CGWindowID,
        connection: ConnectionID
    ) -> [SpaceID]? {
        guard let copySpaces = copySpacesForWindows,
            let windows = windowList(target),
            let spaces = copySpaces(
                connection,
                allSpacesSelector,
                windows
            )?.takeRetainedValue() as? [NSNumber]
        else { return nil }
        return spaces.map(\.uint64Value)
    }

    /// Wraps window ID in CFArray for SkyLight space APIs.
    private static func windowList(
        _ id: CGWindowID
    ) -> CFArray? {
        var wid = id
        guard
            let number = CFNumberCreate(
                kCFAllocatorDefault,
                .sInt32Type,
                &wid
            )
        else { return nil }
        return [number] as CFArray
    }
}
