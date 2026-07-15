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
    /// Assigning does NOT resync `detectedFloating`: rules
    /// change hands inside loadConfig's reset→reassign
    /// transaction, so any new assignment site outside it must
    /// follow with `reconcileAll()` or a scoped recheck (#164).
    public var floatRules = FloatRules()

    var observers: [pid_t: AXApplicationObserver] = [:]
    var elements: [pid_t: [WindowID: AXUIElement]] = [:]
    /// Last float-detection verdict per tracked window, so
    /// reconcile can re-check and emit only actual changes
    /// (manual make_floating overrides stay untouched).
    var detectedFloating: [WindowID: Bool] = [:]
    /// Tracked windows whose CGWindow layer read as ignored
    /// once; untracked only if the reading persists (layers
    /// flicker during fullscreen transitions).
    var ignorePending: Set<WindowID> = []
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
        ignorePending = []
    }

    /// Last float-detection verdict of a tracked window —
    /// what `make_auto` returns a window to when the manual
    /// override is cleared (#164). Nil for untracked windows.
    public func detectionVerdict(
        for id: WindowID
    ) -> Bool? {
        detectedFloating[id]
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

    /// KiwiDesk's own windows (the Settings window and any
    /// panels/overlays it creates) must never be managed —
    /// tiling or even floating its own UI is wrong. Opening
    /// Settings promotes the app to `.regular`
    /// (`activateAsRegular`), which otherwise slips past the
    /// `attach` activation-policy gate and tiles the Settings
    /// window, so a retile raises a tiled peer over it and
    /// steals focus on restore (#174). Keyed on the process, so
    /// it is policy-independent and covers every self-window.
    nonisolated static func isOwnProcess(_ pid: pid_t) -> Bool {
        pid == getpid()
    }

    func track(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        // Never manage KiwiDesk's own windows (#174) — the
        // universal funnel guard, backing the `attach` gate.
        guard !Self.isOwnProcess(pid) else { return }
        guard AXHelper.role(of: element) == kAXWindowRole,
            !AXHelper.isMinimized(element),
            var window = AXHelper.snapshot(
                element: element,
                pid: pid,
                app: app
            )
        else { return }
        guard elements[pid]?[window.id] == nil else { return }
        // Some panels must never be managed at all — merely
        // floating them still pins them to a space (issue #21).
        guard
            !FloatDetection.shouldIgnore(
                bundleID: app.bundleID,
                id: window.id
            )
        else { return }
        window.isFloating = FloatDetection.shouldFloat(
            element: element,
            bundleID: app.bundleID,
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
    func reconcile(pid: pid_t, app: AppRef) {
        guard observers[pid] != nil else { return }
        // One window-server snapshot for the whole pass; only
        // apps with an ignore rule need layers at all.
        let layers =
            FloatDetection.hasIgnoreRule(bundleID: app.bundleID)
            ? FloatDetection.windowLayers(pid: pid) : [:]
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
            // A tracked window gets one reading of grace —
            // layers flicker during fullscreen transitions,
            // and untracking on a glitch leaks a spurious
            // destroy/create pair to subscribers.
            if FloatDetection.shouldIgnore(
                bundleID: app.bundleID,
                layer: layers[id] ?? 0
            ) {
                if elements[pid]?[id] != nil,
                    !ignorePending.contains(id)
                {
                    ignorePending.insert(id)
                    live.insert(id)
                }
                continue
            }
            ignorePending.remove(id)
            live.insert(id)
            if elements[pid]?[id] == nil {
                track(element, pid: pid, app: app)
            } else {
                recheckFloat(element, id: id, app: app)
            }
        }
        for id in elements[pid, default: [:]].keys
        where !live.contains(id) {
            elements[pid]?[id] = nil
            detectedFloating[id] = nil
            ignorePending.remove(id)
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
        app: AppRef
    ) {
        let floating = FloatDetection.shouldFloat(
            element: element,
            bundleID: app.bundleID,
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
        app: AppRef
    ) {
        switch note {
        case kAXWindowCreatedNotification:
            track(element, pid: pid, app: app)
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
            reconcile(pid: pid, app: app)
        case kAXWindowDeminiaturizedNotification:
            track(element, pid: pid, app: app)
        case kAXFocusedWindowChangedNotification:
            // Closing a window nearly always moves focus;
            // reconciling here catches missed destroy events.
            reconcile(pid: pid, app: app)
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            // Focus events carry only managed windows: the
            // reconcile above just settled tracking, so an
            // absent id is an ignored panel (issue #21) —
            // reporting it would emit a focus_change with an
            // empty app and retile focus-driven layouts.
            guard elements[pid]?[id] != nil else { return }
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
            // Titles load lazily (Electron/WebKit, and any app
            // mid-launch): a window tracked before its title
            // arrives misses `App:Title` float rules forever
            // without a recheck (#160). Gated on a titled rule
            // for this app so ordinary title churn (browsers,
            // terminals) never pays the window-server lookup.
            if elements[pid]?[id] != nil,
                floatRules.hasTitleRule(bundleID: app.bundleID)
            {
                recheckFloat(element, id: id, app: app)
            }
        default:
            break
        }
    }
}
