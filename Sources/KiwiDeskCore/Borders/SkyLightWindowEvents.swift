import CoreFoundation
import CoreGraphics
import Darwin

fileprivate typealias SkyLightNotifyProc =
    @convention(c) (
        UInt32,
        UnsafeMutableRawPointer?,
        Int,
        UnsafeMutableRawPointer?
    ) -> Void

/// Process-lifetime WindowServer notification pump for focus borders
/// (#285 Tier 2). Registration has no reliable public unregister seam,
/// so callbacks never retain a `BorderManager`; the current manager is
/// a weak sink that can be replaced after an in-process stop/start.
@MainActor
final class SkyLightWindowEvents {
    enum Kind: UInt32, CaseIterable {
        case close = 804
        case move = 806
        case resize = 807
        case reorder = 808
        case level = 811
        case unhide = 815
        case hide = 816

        var action: Action {
            switch self {
            case .move, .resize:
                return .follow
            case .reorder, .level:
                return .reorder
            case .unhide:
                return .followAndReorder
            case .hide, .close:
                return .hide
            }
        }

        /// Geometry events (a move/resize burst) coalesce with an
        /// adjacent one for the same window; control events never
        /// do, so their order against geometry is preserved.
        var isGeometry: Bool {
            self == .move || self == .resize
        }
    }

    enum Action: Equatable {
        case follow
        case reorder
        case followAndReorder
        case hide
    }

    fileprivate typealias RegisterNotifyFn =
        @convention(c) (
            SkyLightNotifyProc?, UInt32, UnsafeMutableRawPointer?
        ) -> CGError
    typealias RequestNotificationsFn =
        @convention(c) (
            SkyLight.ConnectionID,
            UnsafeMutablePointer<CGWindowID>?,
            Int32
        ) -> CGError
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

    static let shared: SkyLightWindowEvents? = SkyLightWindowEvents()
    private static weak var active: SkyLightWindowEvents?

    private static let registerNotify: RegisterNotifyFn? =
        SkyLight.symbol(
            "SLSRegisterNotifyProc",
            as: RegisterNotifyFn.self
        )
    private static let requestNotifications: RequestNotificationsFn? =
        SkyLight.symbol(
            "SLSRequestNotificationsForWindows",
            as: RequestNotificationsFn.self
        )
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

    private weak var manager: BorderManager?
    private let connection: SkyLight.ConnectionID
    private let machPort: CFMachPort
    private let runLoopSource: CFRunLoopSource
    private var lastRequested: Set<WindowID>?
    private lazy var deliveryQueue = SkyLightWindowEventQueue {
        [weak self] event in
        self?.manager?.handleSkyLightEvent(
            event.kind,
            window: event.window
        )
    }

    private init?() {
        guard let connection = SkyLight.connection,
            SkyLight.getWindowBounds != nil,
            let registerNotify = Self.registerNotify,
            let getEventPort = Self.getEventPort,
            Self.requestNotifications != nil,
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

        for kind in Kind.allCases {
            guard
                registerNotify(
                    skyLightWindowNotifyCallback,
                    kind.rawValue,
                    nil
                ) == .success
            else { return nil }
        }
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

    func attach(_ manager: BorderManager) {
        self.manager = manager
    }

    /// Requests notifications for these target windows. This private
    /// API's replacement-vs-additive semantics are undocumented;
    /// `lastRequested` only suppresses an identical repeat. If it is
    /// additive, stale deliveries continue but the manager drops any
    /// window it no longer watches (no overlay and not sticky-tracked
    /// — see `handleSkyLightEvent`). An empty request is therefore a
    /// best-effort clear, not a teardown guarantee.
    func watch(_ windows: Set<WindowID>) -> Bool {
        if lastRequested == windows { return true }
        guard let request = Self.requestNotifications else {
            return false
        }
        var ids = windows.map(\.raw)
        if ids.isEmpty {
            let success = request(connection, nil, 0) == .success
            if success { lastRequested = windows }
            return success
        }
        let success = ids.withUnsafeMutableBufferPointer { buffer in
            request(
                connection,
                buffer.baseAddress,
                Int32(buffer.count)
            ) == .success
        }
        if success { lastRequested = windows }
        return success
    }

    fileprivate static func deliver(
        code: UInt32,
        window: CGWindowID
    ) {
        guard let kind = Kind(rawValue: code) else { return }
        Self.active?.deliveryQueue.enqueue(
            kind,
            window: WindowID(window)
        )
    }

    fileprivate static func drain() {
        guard let active, let connection = SkyLight.connection,
            let nextEvent
        else { return }
        active.deliveryQueue.beginDrain()
        defer { active.deliveryQueue.endDrain() }
        while let event = nextEvent(connection) {
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

private let skyLightWindowNotifyCallback: SkyLightNotifyProc = {
    event,
    data,
    length,
    _ in
    guard let data,
        length >= MemoryLayout<CGWindowID>.size
    else { return }
    // Copy before returning to SkyLight: the payload storage is
    // owned by the event currently being drained.
    let window = data.loadUnaligned(as: CGWindowID.self)
    let send: @MainActor @Sendable () -> Void = {
        SkyLightWindowEvents.deliver(
            code: event,
            window: window
        )
    }
    if pthread_main_np() != 0 {
        MainActor.assumeIsolated { send() }
    } else {
        DispatchQueue.main.async(execute: send)
    }
}

private func skyLightEventPortCallback(
    _ port: CFMachPort?,
    _ message: UnsafeMutableRawPointer?,
    _ size: CFIndex,
    _ context: UnsafeMutableRawPointer?
) {
    let drain: @MainActor @Sendable () -> Void = {
        SkyLightWindowEvents.drain()
    }
    if pthread_main_np() != 0 {
        MainActor.assumeIsolated { drain() }
    } else {
        DispatchQueue.main.async(execute: drain)
    }
}
