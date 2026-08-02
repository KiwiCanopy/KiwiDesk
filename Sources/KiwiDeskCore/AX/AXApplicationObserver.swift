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
    func observe(window: AXUIElement)
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

    public init?(pid: pid_t) {
        self.pid = pid
        self.appElement = AXHelper.appElement(pid: pid)

        var created: AXObserver?
        guard
            AXObserverCreate(pid, axCallback, &created)
                == .success,
            let created
        else { return nil }
        observer = created

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.appNotifications {
            AXObserverAddNotification(
                created,
                appElement,
                name as CFString,
                refcon
            )
        }
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(created),
            .defaultMode
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
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        self.observer = nil
    }
}
