import Foundation
import ObjectiveC

/// Runtime bridge to SkyLight's `SLSBridged*Operation` window-management
/// classes (#884, #889). Tested via `WMBridgeSeamTests`.
@MainActor
public enum WMBridge {
    public typealias SpaceID = SkyLight.SpaceID

    /// Prefix joined to short operation names at runtime lookup.
    static let classPrefix = "SLSBridged"

    /// Stored desktop store prefix (#889 item 3).
    public static let valueKeyPrefix = "kiwidesk."

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

    /// Reads typed field from result object if selector is supported.
    static func field<T>(_ key: String, of result: NSObject?) -> T? {
        guard let result,
            result.responds(to: NSSelectorFromString(key))
        else { return nil }
        return result.value(forKey: key) as? T
    }
}
