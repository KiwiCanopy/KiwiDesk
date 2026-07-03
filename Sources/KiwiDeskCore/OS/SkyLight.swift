import CoreFoundation
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
    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
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
}
