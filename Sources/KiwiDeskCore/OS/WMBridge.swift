import Foundation
import ObjectiveC

/// Runtime bridge to SkyLight's `SLSBridged*Operation`
/// window-management classes (#884, #889); `WMBridgeSeamTests`
/// pins that every bridge call routes through this file.
/// Main-actor deliberately: #889 probed the operations on the
/// main thread only, and the first `isAvailable` read is a live
/// WindowServer round trip inside a once-initialiser — a hop to
/// main from inside that lock while main waited on it would
/// deadlock.
@MainActor
public enum WMBridge {
    public typealias SpaceID = SkyLight.SpaceID

    /// Prefix joined to short operation names at runtime lookup.
    static let classPrefix = "SLSBridged"

    /// Stored desktop-store key prefix (#889 item 3). A STORED
    /// value (AGENTS.md §5): the WindowServer persists these keys
    /// across logout, so a change to this string owes a re-stamp
    /// crossing for every Desktop carrying the old one — never a
    /// reader lenient to both.
    /// `nonisolated`: the READ door is the plain WindowServer
    /// plist, parsed off the main actor (#1147), so a
    /// main-actor-bound constant would force the prefix to be
    /// spelled a second time there — which is the one thing the
    /// crossing rule above cannot survive.
    public nonisolated static let valueKeyPrefix = "kiwidesk."

    /// Transforms dictionary keys under `valueKeyPrefix`.
    static func namespaced(_ values: [String: Any]) -> NSDictionary {
        var out: [String: Any] = [:]
        for (key, value) in values {
            out[valueKeyPrefix + key] = value
        }
        return out as NSDictionary
    }

    #if DEBUG
        /// Test seam for injecting mocked operation classes.
        public static var classResolverOverride: ((String) -> AnyClass?)?
    #endif

    /// True if framework is loaded and operation classes resolve (#884, #889).
    public static var isAvailable: Bool {
        #if DEBUG
            if classResolverOverride != nil {
                return probeAvailability()
            }
        #endif
        return cachedAvailability
    }

    private static let cachedAvailability: Bool = probeAvailability()

    private static func probeAvailability() -> Bool {
        managedDisplaySpaces() != nil
    }

    /// Resolves class for operation short name, or nil if unavailable.
    static func resolve(_ operation: String) -> AnyClass? {
        #if DEBUG
            if let override = classResolverOverride {
                return override(operation)
            }
        #endif
        guard SkyLight.isLoaded else { return nil }
        return NSClassFromString(classPrefix + operation)
    }

    /// `objc_msgSend`, typed per call: the initialisers take C
    /// scalars `perform(_:with:)` cannot pass, and the async
    /// `perform…` returns VOID — read through `perform(_:)` that
    /// is a stale register, not a result.
    private nonisolated(unsafe) static let send: UnsafeMutableRawPointer? =
        dlsym(dlopen(nil, RTLD_LAZY), "objc_msgSend")

    private typealias AllocFn =
        @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
    typealias InitFn =
        @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
    typealias InitObjectFn =
        @convention(c) (AnyObject, Selector, AnyObject)
        -> Unmanaged<AnyObject>?
    typealias InitObjectIDFn =
        @convention(c) (AnyObject, Selector, AnyObject, UInt64)
        -> Unmanaged<AnyObject>?
    typealias InitObjectObjectFn =
        @convention(c) (AnyObject, Selector, AnyObject, AnyObject)
        -> Unmanaged<AnyObject>?
    typealias InitIDFn =
        @convention(c) (AnyObject, Selector, UInt64)
        -> Unmanaged<AnyObject>?
    typealias InitIDObjectFn =
        @convention(c) (AnyObject, Selector, UInt64, AnyObject)
        -> Unmanaged<AnyObject>?
    typealias InitOptionsObjectFn =
        @convention(c) (AnyObject, Selector, UInt32, AnyObject)
        -> Unmanaged<AnyObject>?
    private typealias SyncPerformFn =
        @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
    private typealias AsyncPerformFn =
        @convention(c) (AnyObject, Selector) -> Void

    private static let performSelector = NSSelectorFromString(
        "performWithWMBridgeDelegate"
    )

    static func sender<T>(as type: T.Type) -> T? {
        send.map { unsafeBitCast($0, to: T.self) }
    }

    /// Allocates and initializes operation object.
    static func make(
        _ operation: String,
        initializer: String,
        _ build: (AnyObject, Selector) -> Unmanaged<AnyObject>?
    ) -> AnyObject? {
        guard let cls = resolve(operation),
            let alloc = sender(as: AllocFn.self),
            let instance = alloc(cls, NSSelectorFromString("alloc"))
        else { return nil }
        return build(
            instance.takeUnretainedValue(),
            NSSelectorFromString(initializer)
        )?.takeRetainedValue()
    }

    /// Executes synchronous operation returning result object.
    static func performSync(_ operation: AnyObject?) -> NSObject? {
        guard let operation,
            let perform = sender(as: SyncPerformFn.self)
        else { return nil }
        return perform(operation, performSelector)?
            .takeUnretainedValue() as? NSObject
    }

    /// Dispatches asynchronous operation to bridge (#889).
    static func performAsync(_ operation: AnyObject?) -> Bool {
        guard let operation,
            let perform = sender(as: AsyncPerformFn.self)
        else { return false }
        perform(operation, performSelector)
        return true
    }

    /// Reads a typed field from a result object, only where the
    /// selector is supported: `value(forKey:)` on an unknown key
    /// raises an ObjC exception Swift cannot catch — a trap, and
    /// the key is the same release-churn surface as the class.
    static func field<T>(_ key: String, of result: NSObject?) -> T? {
        guard let result,
            result.responds(to: NSSelectorFromString(key))
        else { return nil }
        return result.value(forKey: key) as? T
    }
}
