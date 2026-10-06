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

    static let shared: SkyLightEventPort? = SkyLightEventPort()
    private static weak var active: SkyLightEventPort?

    private static let getEventPort: GetEventPortFn? =
        SkyLight.symbol(
            "SLSGetEventPort",
            as: GetEventPortFn.self
        )
    private static let nextEvent: NextEventFn? = SkyLight.symbol(
        "SLEventCreateNextEvent",
        as: NextEventFn.self
    )
    private static let setMachPortOptions: SetMachPortOptionsFn? =
        coreFoundationSymbol(
            "_CFMachPortSetOptions",
            as: SetMachPortOptionsFn.self
        )

    let connection: SkyLight.ConnectionID
    private let machPort: CFMachPort
    private let runLoopSource: CFRunLoopSource
    private var drainObservers: [(begin: () -> Void, end: () -> Void)] = []

    private init?() {
        guard let connection = SkyLight.connection,
            let getEventPort = Self.getEventPort,
            Self.nextEvent != nil,
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

    /// Brackets every drain: `begin` before the notify procs
    /// fire for the drained events, `end` after.
    func observeDrain(
        begin: @escaping () -> Void,
        end: @escaping () -> Void
    ) {
        drainObservers.append((begin, end))
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
    ) -> T? {
        let path =
            "/System/Library/Frameworks/"
            + "CoreFoundation.framework/CoreFoundation"
        guard let handle = dlopen(path, RTLD_LAZY),
            let raw = dlsym(handle, name)
        else { return nil }
        return unsafeBitCast(raw, to: type)
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
