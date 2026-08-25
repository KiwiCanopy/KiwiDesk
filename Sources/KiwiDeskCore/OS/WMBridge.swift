import Foundation
import ObjectiveC

/// Runtime bridge to SkyLight's window-management operation
/// classes (`SLSBridged*Operation`, macOS 26+) — the surface
/// #884 found and #889 probed: moving windows between Desktops,
/// switching the visible Desktop, Desktop lifecycle, sticky
/// membership and the per-Desktop key/value store, all on stock
/// macOS with SIP on.
///
/// The discipline is `SkyLight`'s, extended from C symbols to
/// ObjC classes: every class is looked up by name at runtime
/// (`NSClassFromString` after the framework's `dlopen`), and a
/// class that does not resolve makes the capability ABSENT —
/// every entry point answers nil or false, never traps (#889
/// item 8: an absent class is a nil lookup, verified against
/// three fake names with the real class as the control).
///
/// Three facts every caller has to carry (#889):
///
/// - **Performed is not applied.** An asynchronous operation
///   returns nothing at all, and a synchronous one returns a
///   result even when the WindowServer silently declined
///   (edge reservation performed under every mask and moved
///   nothing). A write is verified by a re-query or by state
///   the caller owns — never by this API's return value.
/// - **The bridge exists only while AppKit is genuinely loaded**
///   (#884's bisection): its load-time init registers the
///   delegate the operations dispatch to. Free in the app,
///   binding on any harness — which is one reason tests reach
///   this type only through `classResolverOverride`.
/// - **No Accessibility trust is needed** for reads or writes;
///   AppKit-loaded is the only gate.
///
/// The `SLSBridged` prefix is spelled ONCE, here, and the
/// operation names are joined to it at lookup — so every
/// bridge call in the tree goes through this file, which
/// `WMBridgeSeamTests` pins by scanning for the prefix.
public enum WMBridge {
    public typealias SpaceID = SkyLight.SpaceID

    /// The one spelling of the class-name prefix (see the type
    /// doc). Joined to an operation's short name at lookup.
    static let classPrefix = "SLSBridged"

    #if DEBUG
        /// Test seam: answers every class lookup instead of the
        /// ObjC runtime, so a suite can hand the plumbing fake
        /// operation classes — or nil, to prove the absent
        /// capability degrades rather than traps — without
        /// touching the machine's WindowServer.
        public static nonisolated(unsafe) var classResolverOverride:
            ((String) -> AnyClass?)?
    #endif

    /// Whether the bridge is usable in THIS process: the
    /// framework loaded, the operation classes resolve, and a
    /// synchronous read answers — which is what proves the
    /// delegate is registered, i.e. that AppKit is really
    /// loaded. A GUI surface offering a bridge feature gates on
    /// this predicate and greys with a reason when it is false.
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

    // MARK: - Class resolution

    /// The class for one operation, by its short name
    /// (`"SpaceCreateOperation"`), or nil when the capability is
    /// absent on this macOS.
    static func resolve(_ operation: String) -> AnyClass? {
        #if DEBUG
            if let override = classResolverOverride {
                return override(operation)
            }
        #endif
        guard SkyLight.isLoaded else { return nil }
        return NSClassFromString(classPrefix + operation)
    }

    // MARK: - Message sending

    /// `objc_msgSend`, typed per call below. The bridge's
    /// initialisers take C scalars (`unsigned long long` space
    /// ids, `unsigned int` option masks) that `perform(_:with:)`
    /// cannot pass, and its asynchronous `perform…` returns
    /// VOID — read through `perform(_:)` that is a stale
    /// register, not a result.
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

    /// `objc_msgSend` as one of the signatures above.
    static func sender<T>(as type: T.Type) -> T? {
        send.map { unsafeBitCast($0, to: T.self) }
    }

    /// Allocates and initialises one operation: `build` receives
    /// the `+alloc`ed instance and the initialiser selector and
    /// returns the initialised object (`-init…` consumes the
    /// allocation, so the pair nets +1 and is taken retained).
    /// Nil when the class or the runtime is unavailable.
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

    /// Performs a SYNCHRONOUS operation and returns its result
    /// object (an `SLSBridgedWindowManagementOperation*Result`,
    /// read by key), or nil when the delegate is absent — the
    /// AppKit-not-loaded case, or a bridge that refused.
    static func performSync(_ operation: AnyObject?) -> NSObject? {
        guard let operation,
            let perform = sender(as: SyncPerformFn.self)
        else { return nil }
        return perform(operation, performSelector)?
            .takeUnretainedValue() as? NSObject
    }

    /// Dispatches an ASYNCHRONOUS operation. True means it was
    /// handed to the bridge — nothing more (see the type doc).
    static func performAsync(_ operation: AnyObject?) -> Bool {
        guard let operation,
            let perform = sender(as: AsyncPerformFn.self)
        else { return false }
        perform(operation, performSelector)
        return true
    }

    /// One typed field of a result object, by its declared
    /// property name (`spaceID`, `numbers`, `string`, …).
    static func field<T>(_ key: String, of result: NSObject?) -> T? {
        result?.value(forKey: key) as? T
    }
}
