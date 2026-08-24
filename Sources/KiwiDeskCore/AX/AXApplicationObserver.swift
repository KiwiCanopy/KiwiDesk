import AppKit
import ApplicationServices

/// C entry point for AX notifications. The run loop source is
/// registered on the main run loop, so this always fires on the
/// main thread (see AGENTS.md guardrails).
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
    // AXUIElement is a CF type without Sendable annotation; we
    // stay on the main thread here, so this is safe.
    nonisolated(unsafe) let unsafeElement = element
    MainActor.assumeIsolated {
        wrapper.onNotification(name, unsafeElement)
    }
}

/// What `EventLoop` needs from a per-app observer — the seam
/// that lets lifecycle and warmup tests drive the attach and
/// reconcile funnels without registering real `AXObserver`s on
/// the host's apps (tests.md; the `HotkeyRegistrar` shape).
/// Production always goes through `AXApplicationObserver` via
/// `EventLoop.makeObserver`'s live default.
@MainActor
protocol AppObserving: AnyObject {
    var onNotification: @MainActor (String, AXUIElement) -> Void {
        get set
    }
    /// True while any app-level notification add is still
    /// unregistered (#675) — a fresh-launch app can refuse the
    /// adds, after which the observer sits installed and silent.
    /// Required, no protocol-extension default: a `false`
    /// default is the deaf-observer shape this seam exists to
    /// fix, and a conformer that drifted off the real members
    /// would inherit it silently. Every fake states its health.
    var needsRegistrationRepair: Bool { get }
    func observe(window: AXUIElement)
    /// Re-attempts the app-level adds that failed (#675).
    func repairRegistration()
    func invalidate()
}

extension AXApplicationObserver: AppObserving {}

/// Observes Accessibility notifications for one application.
///
/// App-level notifications (window created, focus changed) are
/// registered on the app element. Per-window notifications
/// (destroyed, moved, resized, title) must be registered on each
/// window element via `observe(window:)`.
@MainActor
public final class AXApplicationObserver {
    public typealias Handler =
        @MainActor (String, AXUIElement) -> Void

    public let pid: pid_t
    public let appElement: AXUIElement
    public var onNotification: Handler = { _, _ in }

    private var observer: AXObserver?
    /// The run loop modes this observer's source is registered
    /// in — read by both the add and the remove, so the two can
    /// never name different modes and strand the source.
    private let runLoopModes: [CFRunLoopMode]
    /// App-level names whose `AXObserverAddNotification` did not
    /// succeed (#675). A fresh-launch app whose AX tree is not
    /// ready yet refuses the add; discarding that result left the
    /// observer installed but deaf — no `windowCreated` AND no
    /// `focusedWindowChanged`, so both the primary path and its
    /// safety net were dead, and the non-nil `observers[pid]`
    /// entry blocked any re-attach forever.
    private var failedAppNotifications: Set<String> = []

    /// Registered on the app element: delivered app-wide for
    /// all (including future) windows. Miniaturize events are
    /// only reliable at this level.
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

    /// Which run loop modes an app's notification source
    /// belongs in. AX notifications for EVERY observed app are
    /// delivered on OUR run loop, and a source registered only
    /// in `.defaultMode` is deaf while that run loop runs a
    /// tracking loop — which our own window's live resize is,
    /// in THIS process, for exactly its duration (#953).
    ///
    /// So the own process, and only it, also registers in the
    /// event-tracking mode — those two by name, never
    /// `.commonModes`, which carries a third nobody asked for.
    ///
    /// Why only the own process, why not the common set, and
    /// what the two registration sites owe this list: once, in
    /// `.claude/rules/accessibility.md` under #953. Do not
    /// reproduce it here.
    static func runLoopModes(pid: pid_t) -> [CFRunLoopMode] {
        guard EventLoop.isOwnProcess(pid) else {
            return [.defaultMode]
        }
        return [.defaultMode, eventTracking]
    }

    /// `NSEventTrackingRunLoopMode` as a `CFRunLoopMode` —
    /// AppKit spells it only as a `RunLoop.Mode`.
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

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.appNotifications {
            let result = AXObserverAddNotification(
                created,
                appElement,
                name as CFString,
                refcon
            )
            if !Self.registered(result) {
                failedAppNotifications.insert(name)
            }
        }
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

    public var needsRegistrationRepair: Bool {
        !failedAppNotifications.isEmpty
    }

    /// Re-attempts the app-level adds that failed at init (#675).
    /// Driven from every reconcile touchpoint and the adoption
    /// heal sweep, whose cadence is the retry backoff — no timer
    /// of its own.
    public func repairRegistration() {
        guard let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in failedAppNotifications {
            let result = AXObserverAddNotification(
                observer,
                appElement,
                name as CFString,
                refcon
            )
            if Self.registered(result) {
                failedAppNotifications.remove(name)
            }
        }
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
