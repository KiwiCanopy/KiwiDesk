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
    /// Last float-detection verdict per tracked window, so
    /// reconcile can re-check and emit only actual changes
    /// (manual make_floating overrides stay untouched).
    var detectedFloating: [WindowID: Bool] = [:]
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
        detectedFloating = [:]
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

    /// Whether the window's app still lists it via AX. False
    /// for windows on another native macOS Space — raising
    /// one of those would yank macOS back to that Space.
    public func isListed(_ id: WindowID) -> Bool {
        guard
            let pid = elements.first(
                where: { $1[id] != nil }
            )?.key
        else { return false }
        return AXHelper.windows(pid: pid).contains {
            AXHelper.windowID(of: $0) == id
        }
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
        // Some panels must never be managed at all — merely
        // floating them still pins them to a space (issue #21).
        guard
            !FloatDetection.shouldIgnore(
                element: element,
                appName: appName
            )
        else { return }
        window.isFloating = FloatDetection.shouldFloat(
            element: element,
            appName: appName,
            rules: floatRules
        )
        detectedFloating[window.id] = window.isFloating
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
        var minimized: Set<WindowID> = []
        for element in AXHelper.windows(pid: pid) {
            guard let id = AXHelper.windowID(of: element)
            else { continue }
            // Minimized windows count as gone. Unlike windows
            // missing from the list entirely (other native
            // Space), they are flagged so state forgets their
            // space (see KiwiEvent.windowDestroyed).
            guard !AXHelper.isMinimized(element) else {
                minimized.insert(id)
                continue
            }
            // An ignored panel stays out of `live`: if the
            // startup scan mistracked it (its layer reads
            // wrong mid-launch), the sweep below untracks it.
            guard
                !FloatDetection.shouldIgnore(
                    element: element,
                    appName: appName
                )
            else { continue }
            live.insert(id)
            if elements[pid]?[id] == nil {
                track(element, pid: pid, appName: appName)
            } else {
                recheckFloat(element, id: id, appName: appName)
            }
        }
        for id in elements[pid, default: [:]].keys
        where !live.contains(id) {
            elements[pid]?[id] = nil
            detectedFloating[id] = nil
            onEvent(
                .windowDestroyed(
                    id,
                    wasMinimized: minimized.contains(id)
                )
            )
        }
    }

    /// Re-runs float detection on an already-tracked window.
    /// A window scanned mid-launch or mid-animation can report
    /// a wrong subrole once (Ghostty's quick terminal during
    /// the startup scan) and would otherwise stay misclassified
    /// until it closes. Only a changed detection verdict emits,
    /// so manual make_floating overrides survive reconciles.
    private func recheckFloat(
        _ element: AXUIElement,
        id: WindowID,
        appName: String
    ) {
        let floating = FloatDetection.shouldFloat(
            element: element,
            appName: appName,
            rules: floatRules
        )
        guard detectedFloating[id] != floating else { return }
        detectedFloating[id] = floating
        onEvent(.windowFloatChanged(id, isFloating: floating))
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
                detectedFloating[id] = nil
                onEvent(
                    .windowDestroyed(
                        id,
                        wasMinimized: note
                            == kAXWindowMiniaturizedNotification
                    )
                )
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
