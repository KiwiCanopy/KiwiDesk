import AppKit
import ApplicationServices

/// Central listener for system events.
///
/// Watches app launches/terminations via `NSWorkspace` (see
/// EventLoop+Apps.swift), attaches an `AXApplicationObserver`
/// per app, and translates raw AX notifications into typed
/// `KiwiEvent`s. It keeps no layout state itself — consumers
/// apply events to the state managers.
@MainActor
public final class EventLoop {
    public var onEvent: @MainActor (KiwiEvent) -> Void = { _ in }

    /// User float rules from the Lua config (`float_rules`).
    public var floatRules = FloatRules()

    var observers: [pid_t: AXApplicationObserver] = [:]
    var elements: [pid_t: [WindowID: AXUIElement]] = [:]
    var workspaceTokens: [NSObjectProtocol] = []
    var screenToken: NSObjectProtocol?
    var lastActivePid: pid_t?
    public private(set) var isRunning = false

    public init() {}

    // MARK: - Lifecycle

    /// Starts observing. Requires Accessibility permission.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        registerWorkspaceObservers()
        for app in NSWorkspace.shared.runningApplications {
            attach(app: app)
        }
        publishDisplays()
    }

    /// Stops observing and forgets all tracked windows.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        let center = NSWorkspace.shared.notificationCenter
        for token in workspaceTokens {
            center.removeObserver(token)
        }
        workspaceTokens = []
        if let screenToken {
            NotificationCenter.default
                .removeObserver(screenToken)
        }
        screenToken = nil
        for observer in observers.values {
            observer.invalidate()
        }
        observers = [:]
        elements = [:]
    }

    /// AX element of a tracked window, if still known. Used to
    /// apply geometry (animations, wake restore) to windows.
    public func element(for id: WindowID) -> AXUIElement? {
        for perApp in elements.values {
            if let element = perApp[id] {
                return element
            }
        }
        return nil
    }

    // MARK: - Window tracking

    func track(
        _ element: AXUIElement,
        pid: pid_t,
        appName: String
    ) {
        guard AXHelper.role(of: element) == kAXWindowRole,
            !AXHelper.isMinimized(element),
            var window = AXHelper.snapshot(
                element: element,
                pid: pid,
                appName: appName
            )
        else { return }
        guard elements[pid]?[window.id] == nil else { return }
        window.isFloating = FloatDetection.shouldFloat(
            element: element,
            appName: appName,
            rules: floatRules
        )
        elements[pid, default: [:]][window.id] = element
        observers[pid]?.observe(window: element)
        onEvent(.windowCreated(window))
    }

    /// Syncs tracked windows with the app's live AX window
    /// list. Removes windows that closed or minimized, and
    /// picks up windows we missed (e.g. deminiaturized).
    /// Safety net for macOS's unreliable AX notifications —
    /// without it, closed windows keep occupying layout slots.
    func reconcile(pid: pid_t, appName: String) {
        guard observers[pid] != nil else { return }
        var live: Set<WindowID> = []
        for element in AXHelper.windows(pid: pid) {
            guard let id = AXHelper.windowID(of: element)
            else { continue }
            // Minimized windows count as gone.
            guard !AXHelper.isMinimized(element) else {
                continue
            }
            live.insert(id)
            if elements[pid]?[id] == nil {
                track(element, pid: pid, appName: appName)
            }
        }
        for id in elements[pid, default: [:]].keys
        where !live.contains(id) {
            elements[pid]?[id] = nil
            onEvent(.windowDestroyed(id))
        }
    }

    private func windowID(
        of element: AXUIElement,
        pid: pid_t
    ) -> WindowID? {
        if let id = AXHelper.windowID(of: element) {
            return id
        }
        // Destroyed elements no longer answer queries; fall back
        // to comparing against tracked elements.
        return elements[pid, default: [:]]
            .first { CFEqual($1, element) }?.key
    }

    func handle(
        _ note: String,
        _ element: AXUIElement,
        pid: pid_t,
        appName: String
    ) {
        switch note {
        case kAXWindowCreatedNotification:
            track(element, pid: pid, appName: appName)
        case kAXUIElementDestroyedNotification,
            kAXWindowMiniaturizedNotification:
            if let id = windowID(of: element, pid: pid),
                elements[pid]?[id] != nil
            {
                elements[pid]?[id] = nil
                onEvent(.windowDestroyed(id))
            }
            // Destroyed elements often cannot be mapped back
            // (and some apps skip the notification entirely),
            // so always diff against the live window list.
            reconcile(pid: pid, appName: appName)
        case kAXWindowDeminiaturizedNotification:
            track(element, pid: pid, appName: appName)
        case kAXFocusedWindowChangedNotification:
            // Closing a window nearly always moves focus;
            // reconciling here catches missed destroy events.
            reconcile(pid: pid, appName: appName)
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(.windowFocused(id))
        case kAXWindowMovedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(
                .windowMoved(
                    id,
                    AXHelper.frame(of: element)
                )
            )
        case kAXWindowResizedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(
                .windowResized(
                    id,
                    AXHelper.frame(of: element)
                )
            )
        case kAXTitleChangedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(
                .windowTitleChanged(
                    id,
                    AXHelper.title(of: element)
                )
            )
        default:
            break
        }
    }
}
