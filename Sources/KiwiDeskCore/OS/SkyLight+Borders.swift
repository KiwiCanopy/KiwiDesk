import CoreFoundation
import CoreGraphics
import Foundation

/// Runtime-only SkyLight surface used by the focus-border fast path
/// (#285 Tier 2). Every symbol is optional: callers must gate on
/// `borderRenderingAvailable` and fall back to AppKit after any
/// failed operation.
extension SkyLight {
    typealias NewRegionWithRectFn =
        @convention(c) (
            UnsafePointer<CGRect>,
            UnsafeMutablePointer<Unmanaged<CFTypeRef>?>
        ) -> CGError
    typealias NewWindowFn =
        @convention(c) (
            ConnectionID,
            Int32,
            Float,
            Float,
            CFTypeRef,
            UnsafeMutablePointer<CGWindowID>
        ) -> CGError
    typealias ReleaseWindowFn =
        @convention(c) (
            ConnectionID, CGWindowID
        ) -> CGError
    typealias SetWindowShapeFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            Float,
            Float,
            CFTypeRef
        ) -> CGError
    typealias SetWindowResolutionFn =
        @convention(c) (
            ConnectionID, CGWindowID, Double
        ) -> CGError
    typealias SetWindowTagsFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            UnsafePointer<UInt64>,
            Int32
        ) -> CGError
    typealias SetWindowOpacityFn =
        @convention(c) (
            ConnectionID, CGWindowID, Bool
        ) -> CGError
    typealias SetShadowParametersFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            Float,
            Float,
            Int32,
            Int32
        ) -> CGError
    typealias WindowContextCreateFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            CFDictionary?
        ) -> Unmanaged<CGContext>?
    typealias FlushWindowContentFn =
        @convention(c) (
            ConnectionID, CGWindowID, UnsafeMutableRawPointer?
        ) -> CGError
    typealias WindowFreezeFn =
        @convention(c) (
            ConnectionID, CGWindowID, CFTypeRef?
        ) -> CGError
    typealias WindowThawFn =
        @convention(c) (
            ConnectionID, CGWindowID
        ) -> CGError
    typealias GetWindowBoundsFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            UnsafeMutablePointer<CGRect>
        ) -> CGError
    typealias GetWindowLevelFn =
        @convention(c) (
            ConnectionID,
            CGWindowID,
            UnsafeMutablePointer<Int64>
        ) -> CGError
    typealias GetWindowSubLevelFn =
        @convention(c) (
            ConnectionID, CGWindowID
        ) -> Int32

    typealias TransactionCreateFn =
        @convention(c) (
            ConnectionID
        ) -> Unmanaged<CFTypeRef>?
    typealias TransactionMoveFn =
        @convention(c) (
            CFTypeRef, CGWindowID, CGPoint
        ) -> CGError
    typealias TransactionLevelFn =
        @convention(c) (
            CFTypeRef, CGWindowID, Int32
        ) -> CGError
    typealias TransactionSubLevelFn =
        @convention(c) (
            CFTypeRef, CGWindowID, Int32
        ) -> CGError
    typealias TransactionTransformFn =
        @convention(c) (
            CFTypeRef,
            CGWindowID,
            Int32,
            Int32,
            CGAffineTransform
        ) -> CGError
    typealias TransactionOrderFn =
        @convention(c) (
            CFTypeRef, CGWindowID, Int32, CGWindowID
        ) -> CGError
    typealias TransactionCommitFn =
        @convention(c) (
            CFTypeRef, Int32
        ) -> CGError
    typealias MoveWindowsToManagedSpaceFn =
        @convention(c) (
            ConnectionID, CFArray, SpaceID
        ) -> Void
    typealias CopySpacesForWindowsFn =
        @convention(c) (
            ConnectionID, UInt32, CFArray
        ) -> Unmanaged<CFArray>?

    static let newRegionWithRect: NewRegionWithRectFn? = symbol(
        "CGSNewRegionWithRect",
        as: NewRegionWithRectFn.self
    )
    static let newWindow: NewWindowFn? = symbol(
        "SLSNewWindow",
        as: NewWindowFn.self
    )
    static let releaseWindow: ReleaseWindowFn? = symbol(
        "SLSReleaseWindow",
        as: ReleaseWindowFn.self
    )
    static let setWindowShape: SetWindowShapeFn? = symbol(
        "SLSSetWindowShape",
        as: SetWindowShapeFn.self
    )
    static let setWindowResolution: SetWindowResolutionFn? = symbol(
        "SLSSetWindowResolution",
        as: SetWindowResolutionFn.self
    )
    static let setWindowTags: SetWindowTagsFn? = symbol(
        "SLSSetWindowTags",
        as: SetWindowTagsFn.self
    )
    static let setWindowOpacity: SetWindowOpacityFn? = symbol(
        "SLSSetWindowOpacity",
        as: SetWindowOpacityFn.self
    )
    static let setShadowParameters: SetShadowParametersFn? = symbol(
        "SLSSetWindowShadowParameters",
        as: SetShadowParametersFn.self
    )
    static let windowContextCreate: WindowContextCreateFn? = symbol(
        "SLWindowContextCreate",
        as: WindowContextCreateFn.self
    )
    static let flushWindowContent: FlushWindowContentFn? = symbol(
        "SLSFlushWindowContentRegion",
        as: FlushWindowContentFn.self
    )
    static let windowFreeze: WindowFreezeFn? = symbol(
        "SLSWindowFreezeWithOptions",
        as: WindowFreezeFn.self
    )
    static let windowThaw: WindowThawFn? = symbol(
        "SLSWindowThaw",
        as: WindowThawFn.self
    )
    static let getWindowBounds: GetWindowBoundsFn? = symbol(
        "SLSGetWindowBounds",
        as: GetWindowBoundsFn.self
    )
    static let getWindowLevel: GetWindowLevelFn? = symbol(
        "SLSGetWindowLevel",
        as: GetWindowLevelFn.self
    )
    static let getWindowSubLevel: GetWindowSubLevelFn? = symbol(
        "SLSGetWindowSubLevel",
        as: GetWindowSubLevelFn.self
    )
    static let transactionCreate: TransactionCreateFn? = symbol(
        "SLSTransactionCreate",
        as: TransactionCreateFn.self
    )
    static let transactionMove: TransactionMoveFn? = symbol(
        "SLSTransactionMoveWindowWithGroup",
        as: TransactionMoveFn.self
    )
    static let transactionLevel: TransactionLevelFn? = symbol(
        "SLSTransactionSetWindowLevel",
        as: TransactionLevelFn.self
    )
    static let transactionSubLevel: TransactionSubLevelFn? = symbol(
        "SLSTransactionSetWindowSubLevel",
        as: TransactionSubLevelFn.self
    )
    static let transactionTransform: TransactionTransformFn? = symbol(
        "SLSTransactionSetWindowTransform",
        as: TransactionTransformFn.self
    )
    static let transactionOrder: TransactionOrderFn? = symbol(
        "SLSTransactionOrderWindow",
        as: TransactionOrderFn.self
    )
    static let transactionCommit: TransactionCommitFn? = symbol(
        "SLSTransactionCommit",
        as: TransactionCommitFn.self
    )
    // Space pinning is REQUIRED (folded into
    // `borderRenderingAvailable` below): it is the sole mechanism
    // that hides the SkyLight ring in Mission Control now that the
    // notification-driven observer is gone, so a nil lookup here
    // retires the whole SkyLight backend to the AppKit `.transient`
    // fallback (which self-hides) rather than leaving an unpinned,
    // all-spaces ring floating over the overview.
    static let moveWindowsToManagedSpace: MoveWindowsToManagedSpaceFn? =
        symbol(
            "SLSMoveWindowsToManagedSpace",
            as: MoveWindowsToManagedSpaceFn.self
        )
    static let copySpacesForWindows: CopySpacesForWindowsFn? =
        symbol(
            "SLSCopySpacesForWindows",
            as: CopySpacesForWindowsFn.self
        )

    /// Complete drawing/movement surface. Notification symbols are
    /// checked separately by `SkyLightWindowEvents`; Tier 2 is used
    /// only when both surfaces initialize.
    static var borderRenderingAvailable: Bool {
        connection != nil && newRegionWithRect != nil
            && newWindow != nil && releaseWindow != nil
            && setWindowShape != nil
            && setWindowResolution != nil
            && setWindowTags != nil && setWindowOpacity != nil
            && setShadowParameters != nil
            && windowContextCreate != nil
            && flushWindowContent != nil && windowFreeze != nil
            && windowThaw != nil && getWindowBounds != nil
            && getWindowLevel != nil && getWindowSubLevel != nil
            && transactionCreate != nil
            && transactionMove != nil && transactionLevel != nil
            && transactionSubLevel != nil
            && transactionTransform != nil
            && transactionOrder != nil && transactionCommit != nil
            // Space-pinning is REQUIRED, not best-effort: it is
            // the sole mechanism hiding the SkyLight ring in
            // Mission Control (the old observer is gone). Without
            // it, retire to the AppKit `.transient` fallback.
            && moveWindowsToManagedSpace != nil
            && copySpacesForWindows != nil
    }

    /// `SLSCopySpacesForWindows` selector for all space types.
    private static let allSpacesSelector: UInt32 = 0x7

    /// Pins window to space of target window to prevent floating in
    /// Mission Control.
    static func pinWindow(
        _ window: CGWindowID,
        toSpaceOf target: CGWindowID,
        connection: ConnectionID
    ) -> Bool {
        guard let move = moveWindowsToManagedSpace,
            let windows = windowList(window)
        else { return false }
        guard
            let space =
                windowSpace(target, connection: connection)
                ?? getActiveSpace?(connection)
        else { return false }
        move(connection, windows, space)
        return true
    }

    /// Queries WindowServer for space hosting target window (`SpaceID`).
    private static func windowSpace(
        _ target: CGWindowID,
        connection: ConnectionID
    ) -> SpaceID? {
        guard let copySpaces = copySpacesForWindows,
            let windows = windowList(target),
            let spaces = copySpaces(
                connection,
                allSpacesSelector,
                windows
            )?.takeRetainedValue() as NSArray?,
            let first = spaces.firstObject as? NSNumber
        else { return nil }
        return first.uint64Value
    }

    /// Wraps window ID in CFArray for SkyLight space APIs.
    /// jankyborders packs the id as a signed-32 `CFNumber`; match
    /// it.
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
