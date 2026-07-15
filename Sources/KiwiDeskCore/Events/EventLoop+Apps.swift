import AppKit
import ApplicationServices

/// App lifecycle: NSWorkspace observers, per-app attachment,
/// and display publishing.
extension EventLoop {
    func registerWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let launch = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Queue .main delivers on the main thread, but the
            // closure is nonisolated and Notification is not
            // Sendable; bridge manually.
            let app = note.runningApplication
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.appLaunched(app)
            }
        }
        let terminate = center.addObserver(
            forName:
                NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.runningApplication
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.appTerminated(app)
            }
        }
        let activate = center.addObserver(
            forName:
                NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.runningApplication
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.appActivated(app)
            }
        }
        let space = center.addObserver(
            forName:
                NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.nativeSpaceChanged()
            }
        }
        workspaceTokens = [launch, terminate, activate, space]

        screenToken = NotificationCenter.default.addObserver(
            forName:
                NSApplication
                .didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.publishDisplays()
            }
        }
    }

    private func appLaunched(_ app: NSRunningApplication) {
        attach(app: app)
        onEvent(
            .appLaunched(
                pid: app.processIdentifier,
                name: app.localizedName ?? "?"
            )
        )
    }

    private func appTerminated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        observers[pid]?.invalidate()
        observers[pid] = nil
        for id in elements[pid, default: [:]].keys {
            detectedFloating[id] = nil
            onEvent(.windowDestroyed(id, wasMinimized: false))
        }
        elements[pid] = nil
        onEvent(.appTerminated(pid: pid))
    }

    /// Closing an app's last window moves focus to a DIFFERENT
    /// app, so the closing app never reports anything. On every
    /// app switch, reconcile the app we just left.
    private func appActivated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        if let previous = lastActivePid, previous != pid {
            reconcile(pid: previous, app: AppRef(pid: previous))
        }
        lastActivePid = pid
        // Mirror the focused-changed path: reconcile the
        // activated app first, so a window tracked late (cold
        // Electron tree, other native Space) is known before
        // the managed-window guard below.
        reconcile(pid: pid, app: AppRef(app))
        // Clicking a window of another app only activates the
        // app: if that window was already its app's focused
        // window, no kAXFocusedWindowChanged fires. Report the
        // cross-app focus change ourselves.
        if let element = AXHelper.focusedWindow(pid: pid),
            let id = AXHelper.windowID(of: element),
            // Only managed windows: an ignored panel (issue
            // #21) or a not-yet-tracked window must not leak
            // a focus event with no state behind it.
            elements[pid]?[id] != nil
        {
            onEvent(.windowFocused(id))
        }
    }

    /// The user switched native macOS Spaces. AX only reports
    /// windows on the current space, so reconcile every app:
    /// windows of the previous space leave the layout, windows
    /// of the new space are picked up. The event goes out
    /// first so a bound profile is in place before the new
    /// space's windows are tiled.
    private func nativeSpaceChanged() {
        onEvent(.nativeSpaceChanged)
        reconcileAll()
    }

    /// Re-syncs every attached app against its live AX window
    /// list. Used after native space switches and once shortly
    /// after startup: the startup scan runs against cold AX
    /// trees, and slow responders (Electron/WebKit, see
    /// AGENTS.md) list windows late or mis-report subroles.
    public func reconcileAll() {
        for pid in observers.keys {
            reconcile(pid: pid, app: AppRef(pid: pid))
        }
    }

    /// Attaches AX observation to a regular (Dock-visible) app.
    func attach(app: NSRunningApplication) {
        // Never observe KiwiDesk's own process (#174): opening
        // Settings flips the app to `.regular`, which would
        // otherwise pass the gate below and tile the Settings
        // window. Guarding here means no self-observer, so
        // `reconcile`'s `observers[pid] != nil` check keeps
        // self out of every downstream path too.
        guard !Self.isOwnProcess(app.processIdentifier) else {
            return
        }
        guard app.activationPolicy == .regular else { return }
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        guard let observer = AXApplicationObserver(pid: pid)
        else { return }

        let ref = AppRef(app)
        observer.onNotification = { [weak self] note, element in
            self?.handle(note, element, pid: pid, app: ref)
        }
        observers[pid] = observer
        // Keep Electron/WebKit AX trees warm (see AGENTS.md).
        AXHelper.setEnhancedUserInterface(pid: pid, enabled: true)

        for element in AXHelper.windows(pid: pid) {
            track(element, pid: pid, app: ref)
        }
    }

    // MARK: - Displays

    func publishDisplays() {
        let displays = NSScreen.screens.compactMap { screen in
            screen.kiwiDisplay
        }
        onEvent(.displaysChanged(displays))
    }
}

extension AppRef {
    /// Captures identity + display name from a live app handle.
    init(_ app: NSRunningApplication) {
        self.init(
            bundleID: app.bundleIdentifier,
            name: app.localizedName ?? "?"
        )
    }

    /// Re-derives identity from a pid alone (reconcile paths
    /// that only hold the process id). An app that has since
    /// exited yields a nil bundle id and a `"?"` name — so it
    /// matches no rule, which is the correct outcome for a
    /// process that is gone.
    init(pid: pid_t) {
        let app = NSRunningApplication(processIdentifier: pid)
        self.init(
            bundleID: app?.bundleIdentifier,
            name: app?.localizedName ?? "?"
        )
    }
}

extension Notification {
    /// The `NSRunningApplication` attached to an `NSWorkspace`
    /// app lifecycle notification.
    fileprivate var runningApplication: NSRunningApplication? {
        userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
    }
}

extension NSScreen {
    /// Converts an `NSScreen` into a KiwiDesk display snapshot.
    var kiwiDisplay: Display? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber
        else { return nil }
        return Display(
            id: DisplayID(number.uint32Value),
            name: localizedName,
            frame: frame,
            visibleFrame: visibleFrame
        )
    }
}
