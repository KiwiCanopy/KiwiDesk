import CoreFoundation
import CoreGraphics
import Foundation

/// Runtime bridge to the private SkyLight framework.
///
/// Symbols are resolved with `dlsym` instead of `@_silgen_name`:
/// a linked private symbol that disappears in a macOS update
/// would crash the app at launch, while a failed lookup here
/// simply yields `nil` and the caller falls back to the public
/// Accessibility API. See AGENTS.md guardrails.
public enum SkyLight {
    public typealias ConnectionID = Int32
    public typealias SpaceID = UInt64

    private nonisolated(unsafe) static let handle: UnsafeMutableRawPointer? =
        dlopen(
            "/System/Library/PrivateFrameworks/"
                + "SkyLight.framework/SkyLight",
            RTLD_LAZY
        )

    /// Resolves one C function pointer, or nil if unavailable.
    static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let sym = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(sym, to: T.self)
    }

    // MARK: - Resolved functions

    public typealias MainConnectionFn =
        @convention(c) () -> ConnectionID
    public typealias GetActiveSpaceFn =
        @convention(c) (ConnectionID) -> SpaceID
    public typealias CopyManagedDisplaySpacesFn =
        @convention(c) (ConnectionID) -> Unmanaged<CFArray>?
    public typealias DisplayCurrentSpaceFn =
        @convention(c) (ConnectionID, CFString) -> SpaceID

    public static let mainConnection: MainConnectionFn? =
        symbol(
            "SLSMainConnectionID",
            as: MainConnectionFn.self
        )

    public static let getActiveSpace: GetActiveSpaceFn? =
        symbol(
            "SLSGetActiveSpace",
            as: GetActiveSpaceFn.self
        )

    public static let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFn? =
        symbol(
            "SLSCopyManagedDisplaySpaces",
            as: CopyManagedDisplaySpacesFn.self
        )

    public static let displayCurrentSpace: DisplayCurrentSpaceFn? = symbol(
        "SLSManagedDisplayGetCurrentSpace",
        as: DisplayCurrentSpaceFn.self
    )

    // MARK: - Window level (#418)

    /// `SLSSetWindowLevel(cid, wid, level)` — the non-transacted
    /// write twin of the border code's `SLSGetWindowLevel` read
    /// (`SkyLight+Borders.swift`). Sets a foreign-process window's
    /// server-side stacking level so a floating window renders above
    /// the tiled plane regardless of focus. Fire-and-forget like the
    /// border transactions: the returned `CGError` is unreliable, so
    /// callers never gate on it (#357 lesson).
    public typealias SetWindowLevelFn =
        @convention(c) (
            ConnectionID, CGWindowID, Int32
        ) -> CGError

    public static let setWindowLevel: SetWindowLevelFn? = symbol(
        "SLSSetWindowLevel",
        as: SetWindowLevelFn.self
    )

    // MARK: - Display suppression

    public typealias DisableUpdateFn =
        @convention(c) (ConnectionID) -> Int32
    public typealias ReenableUpdateFn =
        @convention(c) (ConnectionID) -> Int32

    public static let disableUpdate: DisableUpdateFn? =
        symbol(
            "SLSDisableUpdate",
            as: DisableUpdateFn.self
        )
    public static let reenableUpdate: ReenableUpdateFn? =
        symbol(
            "SLSReenableUpdate",
            as: ReenableUpdateFn.self
        )

    /// True when the minimum set of space APIs resolved.
    public static var isAvailable: Bool {
        mainConnection != nil && getActiveSpace != nil
            && copyManagedDisplaySpaces != nil
    }

    /// The process's connection to the window server, if any.
    public static var connection: ConnectionID? {
        guard let mainConnection else { return nil }
        let cid = mainConnection()
        return cid != 0 ? cid : nil
    }

    /// Freezes window-server compositing so multiple AX
    /// frame-sets composite as one visual update. No-op
    /// when SkyLight symbols didn't resolve.
    public static func suppressDisplay() {
        guard let cid = connection,
            let fn = disableUpdate
        else { return }
        _ = fn(cid)
    }

    /// Resumes compositing after `suppressDisplay()`.
    public static func resumeDisplay() {
        guard let cid = connection,
            let fn = reenableUpdate
        else { return }
        _ = fn(cid)
    }
}
