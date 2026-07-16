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

    /// Fired when Ghostty reports its built-in ignored quick-
    /// terminal panel as its focused window. No `.windowFocused`
    /// is emitted for the panel
    /// itself (issue #21), but the panel being active is a
    /// signal KiwiCore keeps: when the panel is dismissed the
    /// app re-reports its managed main window as focused, and
    /// that stale report must not follow focus to the main
    /// window's space (issue #244). Carries the app's pid.
    ///
    /// Relies on AX reporting the panel *element* as focused at
    /// least once while it is up (the untracked-window branch in
    /// EventLoop+Notifications / EventLoop+Apps): that is when
    /// the pid is flagged. Confirmed for Ghostty's quick
    /// terminal by manual pass; a future ignored-panel app that
    /// only ever re-reports its main window would not flag, and
    /// the dismiss follow would return (the pre-fix behavior).
    public var onIgnoredPanelFocus: @MainActor (pid_t) -> Void = { _ in
    }

    /// User float rules from the Lua config (`float_rules`).
    /// Assigning does NOT resync `detectedFloating`: rules
    /// change hands inside loadConfig's reset→reassign
    /// transaction, so any new assignment site outside it must
    /// follow with `reconcileAll()` or a scoped recheck (#164).
    public var floatRules = FloatRules()

    /// Global apps KiwiDesk never manages (`ignore_rules`).
    /// Bundle identifiers match case-insensitively.
    public var ignoreRules = IgnoreRules()

    var observers: [pid_t: AXApplicationObserver] = [:]
    var elements: [pid_t: [WindowID: AXUIElement]] = [:]
    /// AXEnhancedUserInterface state observed before this loop
    /// changed it. An ignore transition or stop restores that
    /// exact value instead of assuming KiwiDesk owned `true`.
    var enhancedUIBaselines: [pid_t: Bool] = [:]
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
        for (pid, baseline) in enhancedUIBaselines
        where !baseline {
            AXHelper.setEnhancedUserInterface(
                pid: pid,
                enabled: false
            )
        }
        observers = [:]
        elements = [:]
        enhancedUIBaselines = [:]
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

    func track(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        let role = AXHelper.role(of: element)
        guard role == kAXWindowRole,
            !AXHelper.isMinimized(element),
            var window = AXHelper.snapshot(
                element: element,
                pid: pid,
                app: app
            )
        else { return }
        guard elements[pid]?[window.id] == nil else { return }
        let subrole = AXHelper.subrole(of: element)
        let layer = FloatDetection.windowLayer(of: window.id)
        guard
            !FloatDetection.isUnbackedAuxiliary(
                role: role,
                subrole: subrole,
                layer: layer
            )
        else { return }
        // Some panels must never be managed at all — merely
        // floating them still pins them to a space (issue #21).
        guard
            !shouldIgnore(
                element,
                pid: pid,
                app: app,
                layer: layer ?? 0
            )
        else {
            return
        }
        window.isFloating =
            shouldForceFloat(pid: pid)
            || FloatDetection.shouldFloat(
                element: element,
                bundleID: app.bundleID,
                layer: layer,
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
        let activationPolicy =
            NSRunningApplication(
                processIdentifier: pid
            )?.activationPolicy ?? .prohibited
        guard
            Self.ownsObservation(
                hasObserver: observers[pid] != nil,
                pid: pid,
                activationPolicy: activationPolicy,
                isIgnored: shouldIgnoreApp(
                    bundleID: app.bundleID
                )
            )
        else {
            detach(pid: pid, restoreEnhancedUI: true)
            return
        }
        // One window-server snapshot for the whole pass; only
        // apps with an ignore rule need layers at all.
        let layers =
            FloatDetection.requiresWindowLayers(
                bundleID: app.bundleID
            ) ? FloatDetection.windowLayers(pid: pid) : [:]
        let liveElements = AXHelper.windows(pid: pid)
        if activationPolicy == .regular
            || liveElements.contains(where: Self.isStandardWindow)
        {
            // A cold app may not answer the baseline EUI read at
            // attach time. Retry on later reconciles until one
            // succeeds, without taking another window snapshot.
            enableEnhancedUI(pid: pid)
        }
        var live: Set<WindowID> = []
        var minimized: Set<WindowID> = []
        for element in liveElements {
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
            if shouldIgnore(
                element,
                pid: pid,
                app: app,
                layer: layers[id]
            ) {
                // App-wide user rules are stable config, not a
                // flickering window-server signal. Apply them
                // immediately; the one-reading grace below is
                // only for Ghostty's layer-scoped built-in.
                if shouldIgnoreApp(bundleID: app.bundleID) {
                    ignorePending.remove(id)
                    continue
                }
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
                recheckFloat(
                    element,
                    id: id,
                    pid: pid,
                    app: app
                )
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
    // Internal (not private): also called by `handle` in
    // EventLoop+Notifications.swift.
    func recheckFloat(
        _ element: AXUIElement,
        id: WindowID,
        pid: pid_t,
        app: AppRef
    ) {
        let floating =
            shouldForceFloat(pid: pid)
            || FloatDetection.shouldFloat(
                element: element,
                bundleID: app.bundleID,
                rules: floatRules
            )
        guard detectedFloating[id] != floating else { return }
        detectedFloating[id] = floating
        onEvent(.windowFloatChanged(id, isFloating: floating))
    }

}
