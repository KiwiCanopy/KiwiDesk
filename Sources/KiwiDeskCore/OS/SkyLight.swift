import CoreFoundation
import Foundation

/// Runtime bridge resolving private SkyLight SPI symbols dynamically
/// via dlsym.
public enum SkyLight {
    public typealias ConnectionID = Int32
    public typealias SpaceID = UInt64

    private nonisolated(unsafe) static let handle: UnsafeMutableRawPointer? =
        dlopen(
            "/System/Library/PrivateFrameworks/"
                + "SkyLight.framework/SkyLight",
            RTLD_LAZY
        )

    /// Whether the framework loaded.
    static var isLoaded: Bool { handle != nil }

    /// Resolves one C function pointer, or nil if unavailable.
    static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let sym = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(sym, to: T.self)
    }

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

    /// Freezes window-server compositing for batched visual updates.
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
