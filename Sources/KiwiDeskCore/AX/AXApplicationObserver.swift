import AppKit
import ApplicationServices

/// C callback for AX notifications on main run loop.
private func axCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let wrapper = Unmanaged<AXApplicationObserver>
        .fromOpaque(refcon)
        .takeUnretainedValue()
    let name = notification as String
    nonisolated(unsafe) let unsafeElement = element
    MainActor.assumeIsolated {
        wrapper.onNotification(name, unsafeElement)
    }
}

/// Interface for application-level accessibility observers
/// (`tests.md`, `HotkeyRegistrar`).
@MainActor
protocol AppObserving: AnyObject {
    var onNotification: @MainActor (String, AXUIElement) -> Void {
        get set
    }
    /// Whether any app-level notification failed registration —
    /// a fresh launch can refuse the adds, leaving a deaf observer
    /// that looks installed (#675).
    var needsRegistrationRepair: Bool { get }
    func observe(window: AXUIElement)
    /// Re-attempts failed app-level notification registrations.
    /// Reconciles call this opportunistically; the census-gated
    /// adoption-heal sweep is the guaranteed backstop (#675).
    func repairRegistration()
    /// Forgets a stalled repair's back-off, so the next touchpoint
    /// repairs again — a stall read while the session rested is no
    /// evidence (#1285).
    func forgetRepairStall()
    func invalidate()
}

extension AppObserving {
    func forgetRepairStall() {}
}

extension AXApplicationObserver: AppObserving {}

/// Observes accessibility notifications for a single application.
@MainActor
public final class AXApplicationObserver {
    public typealias Handler =
        @MainActor (String, AXUIElement) -> Void

    public let pid: pid_t
    public let appElement: AXUIElement
    public var onNotification: Handler = { _, _ in }

    private var observer: AXObserver?
    private let runLoopModes: [CFRunLoopMode]
    /// The app-level registration's failures and last stall.
    private var ledger = ObserverRegistrationLedger()
    /// The clock the back-off is read on.
    var now: () -> ContinuousClock.Instant = { .now }

    private static let appNotifications: [String] = [
        kAXWindowCreatedNotification,
        kAXFocusedWindowChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
    ]

    private static let windowNotifications: [String] = [
        kAXUIElementDestroyedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXTitleChangedNotification,
    ]

    /// Resolves target run loop modes for process observer
    /// (`EventLoop.isOwnProcess`, `.claude/rules/accessibility.md`, #953).
    static func runLoopModes(pid: pid_t) -> [CFRunLoopMode] {
        guard EventLoop.isOwnProcess(pid) else {
            return [.defaultMode]
        }
        return [.defaultMode, eventTracking]
    }

    /// `NSEventTrackingRunLoopMode` as `CFRunLoopMode`.
    static let eventTracking = CFRunLoopMode(
        RunLoop.Mode.eventTracking.rawValue as CFString
    )

    public init?(pid: pid_t) {
        self.pid = pid
        self.appElement = AXHelper.appElement(pid: pid)
        self.runLoopModes = Self.runLoopModes(pid: pid)

        var created: AXObserver?
        guard
            AXObserverCreate(pid, axCallback, &created)
                == .success,
            let created
        else { return nil }
        observer = created

        ledger.record(register(Self.appNotifications), at: now())
        for mode in runLoopModes {
            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(created),
                mode
            )
        }
    }

    private static func registered(_ result: AXError) -> Bool {
        result == .success
            || result == .notificationAlreadyRegistered
    }

    /// Adds `names` on the app element, answering those left
    /// unregistered.
    private func register(_ names: [String]) -> Registration {
        guard let observer else { return (Set(names), nil) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let element = appElement
        return Self.register(names, now: now) { name in
            AXObserverAddNotification(
                observer,
                element,
                name as CFString,
                refcon
            )
        }
    }

    /// An add that took this long spent most of a messaging
    /// timeout, and the app will spend it again on each add left.
    static let stalledAdd = Duration.milliseconds(
        Int(EventLoop.axMessagingTimeoutSeconds * 500)
    )

    /// The names left unregistered, and the add that stalled.
    typealias Registration = (failed: Set<String>, stalled: String?)

    /// Registers `names` in order. Stops at the first add that
    /// stalls and leaves the rest to repair, so an unresponsive
    /// app costs one timeout instead of one per add (#837).
    static func register(
        _ names: [String],
        now: () -> ContinuousClock.Instant,
        add: (String) -> AXError
    ) -> Registration {
        var failed: Set<String> = []
        for (index, name) in names.enumerated() {
            let began = now()
            if !registered(add(name)) { failed.insert(name) }
            if began.duration(to: now()) >= stalledAdd {
                failed.formUnion(names[(index + 1)...])
                return (failed, name)
            }
        }
        return (failed, nil)
    }

    public var needsRegistrationRepair: Bool {
        ledger.needsRepair(now: now())
    }

    public func forgetRepairStall() { ledger.forgetStall() }

    /// Re-attempts failed app-level notification registrations (#675).
    public func repairRegistration() {
        ledger.record(
            register(ledger.repairOrder(of: Self.appNotifications)),
            at: now()
        )
    }

    /// Registers per-window notifications for a window element.
    public func observe(window: AXUIElement) {
        guard let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.windowNotifications {
            AXObserverAddNotification(
                observer,
                window,
                name as CFString,
                refcon
            )
        }
    }

    /// Stops observing and detaches from the run loop.
    public func invalidate() {
        guard let observer else { return }
        for name in Self.appNotifications {
            AXObserverRemoveNotification(
                observer,
                appElement,
                name as CFString
            )
        }
        for mode in runLoopModes {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                mode
            )
        }
        self.observer = nil
    }
}
