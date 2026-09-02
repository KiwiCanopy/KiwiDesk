import CoreFoundation
import CoreGraphics
import Foundation

/// The per-Desktop window list (#1146): which windows a native
/// Space hosts, read from the WindowServer rather than from AX,
/// which lists only the shown Desktop's. Device-probed 2026-09-02
/// (macOS 26.6.2): resolves and answers from a foreign connection
/// in ~0.1 ms per Desktop; `0x2` lists the windows UP on the
/// Space, `0x7` adds the parked ones (minimized, hidden app).
extension SkyLight {
    typealias CopyWindowsWithOptionsAndTagsFn =
        @convention(c) (
            ConnectionID,
            UInt32,
            CFArray,
            UInt32,
            UnsafeMutablePointer<UInt64>,
            UnsafeMutablePointer<UInt64>
        ) -> Unmanaged<CFArray>?

    static let copyWindowsWithOptionsAndTags:
        CopyWindowsWithOptionsAndTagsFn? = symbol(
            "SLSCopyWindowsWithOptionsAndTags",
            as: CopyWindowsWithOptionsAndTagsFn.self
        )

    /// Windows UP on the Space — not minimized, not hidden.
    private static let upWindowsOptions: UInt32 = 0x2
    /// Every window the Space hosts, parked ones included.
    private static let allWindowsOptions: UInt32 = 0x7

    /// Whether the per-Desktop list can be read at all — the
    /// capability gate a census builder checks before promising
    /// an answer (nil ⇒ absent, never faked).
    static var canListSpaceWindows: Bool {
        copyWindowsWithOptionsAndTags != nil && connection != nil
    }

    /// The windows `space` hosts, every owner — nil when the
    /// symbol or the connection is absent OR the call answers
    /// nothing: a failed read is "cannot tell", never an empty
    /// Desktop, or a census built on it would prune every away
    /// window there as closed.
    static func windows(
        on space: SpaceID,
        includingParked: Bool
    ) -> [CGWindowID]? {
        guard let copy = copyWindowsWithOptionsAndTags,
            let connection
        else { return nil }
        var setTags: UInt64 = 0
        var clearTags: UInt64 = 0
        let spaces = [NSNumber(value: space)] as CFArray
        guard
            let list = copy(
                connection,
                0,
                spaces,
                includingParked ? allWindowsOptions : upWindowsOptions,
                &setTags,
                &clearTags
            )?.takeRetainedValue() as? [NSNumber]
        else { return nil }
        return list.map(\.uint32Value)
    }
}
