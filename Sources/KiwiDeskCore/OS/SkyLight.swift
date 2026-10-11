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

    /// Resolves one C function pointer; nil `function` if
    /// unavailable.
    static func symbol<T>(
        _ name: String,
        as type: T.Type
    ) -> PrivateSymbol<T> {
        guard let handle, let sym = dlsym(handle, name) else {
            return PrivateSymbol(name: name, function: nil)
        }
        return PrivateSymbol(
            name: name,
            function: unsafeBitCast(sym, to: T.self)
        )
    }

    public typealias MainConnectionFn =
        @convention(c) () -> ConnectionID
    public typealias GetActiveSpaceFn =
        @convention(c) (ConnectionID) -> SpaceID
    public typealias CopyManagedDisplaySpacesFn =
        @convention(c) (ConnectionID) -> Unmanaged<CFArray>?
    public typealias DisplayCurrentSpaceFn =
        @convention(c) (ConnectionID, CFString) -> SpaceID

    static let mainConnectionSymbol = symbol(
        "SLSMainConnectionID",
        as: MainConnectionFn.self
    )
    public static var mainConnection: MainConnectionFn? {
        mainConnectionSymbol.function
    }

    static let getActiveSpaceSymbol = symbol(
        "SLSGetActiveSpace",
        as: GetActiveSpaceFn.self
    )
    public static var getActiveSpace: GetActiveSpaceFn? {
        getActiveSpaceSymbol.function
    }

    static let copyManagedDisplaySpacesSymbol = symbol(
        "SLSCopyManagedDisplaySpaces",
        as: CopyManagedDisplaySpacesFn.self
    )
    public static var copyManagedDisplaySpaces: CopyManagedDisplaySpacesFn? {
        copyManagedDisplaySpacesSymbol.function
    }

    static let displayCurrentSpaceSymbol = symbol(
        "SLSManagedDisplayGetCurrentSpace",
        as: DisplayCurrentSpaceFn.self
    )
    public static var displayCurrentSpace: DisplayCurrentSpaceFn? {
        displayCurrentSpaceSymbol.function
    }

    public typealias DisableUpdateFn =
        @convention(c) (ConnectionID) -> Int32
    public typealias ReenableUpdateFn =
        @convention(c) (ConnectionID) -> Int32

    static let disableUpdateSymbol = symbol(
        "SLSDisableUpdate",
        as: DisableUpdateFn.self
    )
    public static var disableUpdate: DisableUpdateFn? {
        disableUpdateSymbol.function
    }
    static let reenableUpdateSymbol = symbol(
        "SLSReenableUpdate",
        as: ReenableUpdateFn.self
    )
    public static var reenableUpdate: ReenableUpdateFn? {
        reenableUpdateSymbol.function
    }

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
