import CoreFoundation
import CoreGraphics

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
            && getWindowLevel != nil && transactionCreate != nil
            && transactionMove != nil && transactionLevel != nil
            && transactionTransform != nil
            && transactionOrder != nil && transactionCommit != nil
    }
}
