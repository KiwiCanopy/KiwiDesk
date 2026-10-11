import CoreFoundation
import CoreGraphics
import Darwin

/// The main connection's WindowServer event port, serviced once
/// per process: a notify proc registered with
/// `SLSRegisterNotifyProc` receives nothing until this port is
/// drained (#1877, probe 2026-10-06). Every consumer — the border
/// pump, the window lifecycle wake-up — registers its own codes
/// and brackets the drain through `observeDrain`, never a second
/// `CFMachPort` on the same port.
@MainActor
final class SkyLightEventPort {
    typealias GetEventPortFn =
        @convention(c) (
            SkyLight.ConnectionID,
            UnsafeMutablePointer<mach_port_t>
        ) -> CGError
    typealias NextEventFn =
        @convention(c) (
            SkyLight.ConnectionID
        ) -> Unmanaged<CGEvent>?
    typealias SetMachPortOptionsFn =
        @convention(c) (
            CFMachPort, Int32
        ) -> Void
    typealias NotifyProc =
        @convention(c) (
            UInt32,
            UnsafeMutableRawPointer?,
            Int,
            UnsafeMutableRawPointer?
        ) -> Void
    typealias RegisterNotifyFn =
        @convention(c) (
            NotifyProc?, UInt32, UnsafeMutableRawPointer?
        ) -> CGError

    static let shared: SkyLightEventPort? = SkyLightEventPort()
    private static weak var active: SkyLightEventPort?

    private static let getEventPortSymbol = SkyLight.symbol(
        "SLSGetEventPort",
        as: GetEventPortFn.self
    )
    private static var getEventPort: GetEventPortFn? {
        getEventPortSymbol.function
    }
    private static let nextEventSymbol = SkyLight.symbol(
        "SLEventCreateNextEvent",
        as: NextEventFn.self
    )
    private static var nextEvent: NextEventFn? {
        nextEventSymbol.function
    }
    private static let registerNotifySymbol = SkyLight.symbol(
        "SLSRegisterNotifyProc",
        as: RegisterNotifyFn.self
    )
    private static var registerNotify: RegisterNotifyFn? {
        registerNotifySymbol.function
    }
    private static let setMachPortOptionsSymbol = coreFoundationSymbol(
        "_CFMachPortSetOptions",
        as: SetMachPortOptionsFn.self
    )
    private static var setMachPortOptions: SetMachPortOptionsFn? {
        setMachPortOptionsSymbol.function
    }

    let connection: SkyLight.ConnectionID
    private let machPort: CFMachPort
    private let runLoopSource: CFRunLoopSource
    private var registered: [UInt32: UnsafeRawPointer] = [:]
    private var drainObservers: [(begin: () -> Void, end: () -> Void)] = []

    private init?() {
        guard let connection = SkyLight.connection,
            let getEventPort = Self.getEventPort,
            Self.nextEvent != nil,
            Self.registerNotify != nil,
            let setMachPortOptions = Self.setMachPortOptions
        else { return nil }
        var eventPort: mach_port_t = 0
        guard getEventPort(connection, &eventPort) == .success,
            eventPort != 0
        else { return nil }
        var shouldFreeInfo = DarwinBoolean(false)
        guard
            let machPort = CFMachPortCreateWithPort(
                nil,
                eventPort,
                skyLightEventPortCallback,
                nil,
                &shouldFreeInfo
            )
        else { return nil }
        setMachPortOptions(machPort, 0x40)
        guard
            let source = CFMachPortCreateRunLoopSource(
                nil,
                machPort,
                0
            )
        else { return nil }
        self.connection = connection
        self.machPort = machPort
        runLoopSource = source
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            source,
            CFRunLoopMode.commonModes
        )
        Self.active = self
    }

    /// Registers `proc` for `code` on this port, once per code
    /// per process (registration has no unregister); true when
    /// the code is registered. Registering here is what makes a
    /// proc hear anything, since this port is the one drained.
    /// A code another proc holds is refused, never shared
    /// silently.
    func register(code: UInt32, _ proc: NotifyProc) -> Bool {
        let key = unsafeBitCast(proc, to: UnsafeRawPointer.self)
        if let holder = registered[code] { return holder == key }
        guard let registerNotify = Self.registerNotify,
            registerNotify(proc, code, nil) == .success
        else { return false }
        registered[code] = key
        return true
    }

    /// Brackets every drain: `begin` before the notify procs
    /// fire for the drained events, `end` after.
    func observeDrain(
        begin: @escaping () -> Void,
        end: @escaping () -> Void
    ) {
        drainObservers.append((begin, end))
    }

    /// The port's symbols as `self_test` probes them (#1889), from
    /// the RUNNING port only: `shared` would install one. Every
    /// read row is liveness only — the port's own construction
    /// and registrations are the call that answered.
    static func selfTestProbes() -> [PrivatePathProbe] {
        let home = "SkyLightEventPort"
        let built: @MainActor () -> PrivatePathVerdict = {
            active == nil
                ? .inconclusive("no event port is running")
                : .answered("the running port was built with it")
        }
        return [
            .read(getEventPortSymbol.resolution, home: home, verify: built),
            .read(
                setMachPortOptionsSymbol.resolution,
                home: home,
                verify: built
            ),
            .read(registerNotifySymbol.resolution, home: home) {
                let codes = active?.registered.count ?? 0
                return codes == 0
                    ? .inconclusive("no code is registered")
                    : .answered("\(codes) codes registered")
            },
            // Calling it would consume events the drain is owed.
            .write(nextEventSymbol.resolution, home: home),
        ]
    }

    fileprivate static func drain() {
        guard let active, let nextEvent else { return }
        for observer in active.drainObservers { observer.begin() }
        defer {
            for observer in active.drainObservers { observer.end() }
        }
        while let event = nextEvent(active.connection) {
            _ = event.takeRetainedValue()
        }
    }

    private static func coreFoundationSymbol<T>(
        _ name: String,
        as type: T.Type
    ) -> PrivateSymbol<T> {
        let path =
            "/System/Library/Frameworks/"
            + "CoreFoundation.framework/CoreFoundation"
        guard let handle = dlopen(path, RTLD_LAZY),
            let raw = dlsym(handle, name)
        else { return PrivateSymbol(name: name, function: nil) }
        return PrivateSymbol(
            name: name,
            function: unsafeBitCast(raw, to: type)
        )
    }
}

private func skyLightEventPortCallback(
    _ port: CFMachPort?,
    _ message: UnsafeMutableRawPointer?,
    _ size: CFIndex,
    _ context: UnsafeMutableRawPointer?
) {
    let drain: @MainActor @Sendable () -> Void = {
        SkyLightEventPort.drain()
    }
    if pthread_main_np() != 0 {
        MainActor.assumeIsolated { drain() }
    } else {
        DispatchQueue.main.async(execute: drain)
    }
}
