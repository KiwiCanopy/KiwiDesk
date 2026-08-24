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
    /// The run loop mode this observer's source is registered
    /// in — read by both the add and the remove, so the two can
    /// never name different modes and strand the source.
    private let runLoopMode: CFRunLoopMode
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

    /// Which run loop mode an app's notification source belongs
    /// in. AX notifications for EVERY observed app are delivered
    /// on OUR run loop, and a source registered only in
    /// `.defaultMode` is deaf while that run loop runs a
    /// tracking loop.
    ///
    /// For a third-party app that costs nothing: its user
    /// gestures run a tracking loop in ITS process while ours
    /// sits in default mode. Our OWN window's live resize or
    /// move IS a tracking loop in THIS process (#953) — the main
    /// run loop is in `NSEventTrackingRunLoopMode` for exactly
    /// the duration of the gesture, so a default-mode-only
    /// source misses every `moved`/`resized` notification the
    /// drag pipeline needs and the tiled Settings window
    /// resizes without its neighbours ever hearing about it.
    ///
    /// Narrow on purpose — the own process only. Widening every
    /// observer to the common modes would also let a
    /// third-party AX storm re-enter our menu and slider
    /// tracking loops, which nothing asks for.
    ///
    /// Reading `isOwnProcess` here is not the widening
    /// `input-and-animation.md` bans: that rule governs which
    /// own WINDOW tiles, and a run loop mode has no window to
    /// discriminate by — it is a property of this process's
    /// main run loop, which every own window shares. What each
    /// of those windows then does with a delivered notification
    /// is still decided per window, by the mark.
    static func runLoopMode(pid: pid_t) -> CFRunLoopMode {
        EventLoop.isOwnProcess(pid)
            ? .commonModes : .defaultMode
    }

    public init?(pid: pid_t) {
        self.pid = pid
        self.appElement = AXHelper.appElement(pid: pid)
        self.runLoopMode = Self.runLoopMode(pid: pid)

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
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(created),
            runLoopMode
        )
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
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            runLoopMode
        )
        self.observer = nil
    }
}
