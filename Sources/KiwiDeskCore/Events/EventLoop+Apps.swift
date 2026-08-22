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
        // Hide and unhide are the only signal an app gives
        // when it stops (or resumes) showing windows without
        // destroying them — a ⌘H, or an Electron app hiding
        // itself as its last window closes. `appHideChanged`
        // argues why one arm serves both.
        let hide = center.addObserver(
            forName: NSWorkspace.didHideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.runningApplication
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.appHideChanged(
                    pid: app.processIdentifier,
                    ref: AppRef(app)
                )
            }
        }
        let unhide = center.addObserver(
            forName:
                NSWorkspace.didUnhideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.runningApplication
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.appHideChanged(
                    pid: app.processIdentifier,
                    ref: AppRef(app)
                )
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
        workspaceTokens = [
            launch, terminate, activate, space, hide, unhide,
        ]

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
        syncObservation(
            for: RunningApp(app),
            scanWindowsAtAttach: true
        )
        onEvent(
            .appLaunched(
                pid: app.processIdentifier,
                name: app.localizedName ?? "?"
            )
        )
    }

    private func appTerminated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        detach(pid: pid, restoreEnhancedUI: false)
        onEvent(.appTerminated(pid: pid))
    }

    /// An app hid or unhid: reconcile it (#913). ONE arm for
    /// both directions on purpose — reconcile already asks
    /// `appIsHidden`, so a second arm would be a second copy of
    /// that question, free to disagree with the first.
    ///
    /// The two directions are not equally reliable, though, and
    /// the asymmetry belongs here rather than in `reconcile`,
    /// because this is where the single arm is claimed. Hiding
    /// is a total answer needing no AX at all. Unhiding depends
    /// on a window-list read that can race a cold tree, so it
    /// is the direction that leans on a backstop — the
    /// census-gated heal, which sees the app again the moment
    /// its windows are back on screen.
    ///
    /// Without this arm the drop still lands, but only when
    /// something else reconciles the app: `appActivated`'s
    /// reconcile of the app just left, which a hide produces
    /// because it moves the foreground. That is a beat later
    /// and tied to where focus happens to go, which is a
    /// visibly late release of the tile.
    ///
    /// Reading `appIsHidden` inside the arm rather than taking
    /// the direction from the notification is safe: measured on
    /// device (2026-08-22, macOS 26.6.2), the flag already
    /// reads its settled value when its own notification
    /// fires, in both directions.
    ///
    /// Descriptor-shaped, like `runningApplications`: a test
    /// cannot build an `NSRunningApplication` for a made-up pid,
    /// which would leave the arm below unpinnable (#672 review
    /// made the same call for the scan's app source).
    func appHideChanged(pid: pid_t, ref: AppRef) {
        // Ignored and prohibited apps have no observer; nothing
        // of theirs is tracked, so there is nothing to reconcile
        // (mirrors `appActivated`'s guard).
        guard observers[pid] != nil else { return }
        reconcile(pid: pid, app: ref)
    }

    /// Closing an app's last window moves focus to a DIFFERENT
    /// app, so the closing app never reports anything. On every
    /// app switch, reconcile the app we just left.
    private func appActivated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        // The reconcile below takes this app's window snapshot
        // on the same turn — no second scan at attach (#672).
        syncObservation(
            for: RunningApp(app),
            scanWindowsAtAttach: false
        )
        if let previous = lastActivePid, previous != pid {
            reconcile(pid: previous, app: AppRef(pid: previous))
        }
        lastActivePid = pid
        // Ignored and prohibited apps have no observer. Keep the
        // cross-app bookkeeping above, but never query their AX
        // tree merely because they became active.
        guard observers[pid] != nil else { return }
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
            let id = AXHelper.windowID(of: element)
        {
            // Only managed windows: an ignored panel (issue
            // #21) or a not-yet-tracked window must not leak
            // a focus event with no state behind it. Surface
            // the ignored panel gaining focus, though, so the
            // dismiss report can be distrusted later (#244).
            if elements[pid]?[id] != nil {
                onEvent(.windowFocused(id))
            } else if FloatDetection.isBuiltInIgnoredPanel(
                bundleID: AppRef(app).bundleID,
                id: id,
                isAccessory: Self.classifiesAsOverlay(
                    pid: pid,
                    activationPolicy: app.activationPolicy
                )
            ) {
                onIgnoredPanelFocus(pid)
            }
        }
    }

    /// The user switched native macOS Spaces. AX only reports
    /// windows on the current space, so reconcile every app:
    /// windows of the previous space leave the layout, windows
    /// of the new space are picked up. The event goes out
    /// first so a bound profile is in place before the new
    /// space's windows are tiled.
    private func nativeSpaceChanged() {
        // Stamp before the resync so both the bulk reconcileAll and
        // any targeted reconcile racing it suppress tab coalescing
        // (departed/arrived windows tile to identical frames, #308).
        lastNativeSpaceChange = Date()
        onEvent(.nativeSpaceChanged)
        reconcileAll()
    }

    /// Re-syncs every attached app against its live AX window
    /// list. Used after native space switches and once shortly
    /// after startup: the startup scan runs against cold AX
    /// trees, and slow responders (Electron/WebKit, see
    /// AGENTS.md) list windows late or mis-report subroles.
    public func reconcileAll() {
        let signposter = BootSignpost.signposter
        let span = signposter.beginInterval("reconcileAll")
        defer { signposter.endInterval("reconcileAll", span) }
        // Rules can detach an already-observed app or make a
        // formerly ignored app observable. Synchronize that
        // app-level boundary without reading ignored AX trees.
        // The reconcile loop below snapshots every attached
        // app's windows, so a fresh attach defers its scan to
        // it rather than reading the list twice (#672).
        for app in runningApplications() {
            syncObservation(for: app, scanWindowsAtAttach: false)
        }
        // Suppress native-tab coalescing here: a native-space switch
        // presents the departed space's windows as vanished and the
        // arrived space's as appeared in one pass, and same-app
        // windows tile to identical frames — they would false-merge
        // into a re-key (#308 review). Genuine switches coalesce via
        // the per-window reconciles the AX notifications drive.
        for pid in Array(observers.keys) {
            reconcile(pid: pid, app: AppRef(pid: pid), coalesceTabs: false)
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

/// What the app-lifecycle funnels (`syncObservation`, `attach`,
/// the startup scan, `reconcileAll`) need from a running app.
/// A snapshot value, not the live `NSRunningApplication`, so a
/// test can fabricate one for a made-up pid and drive the
/// funnels through the machine seams (#672 review).
struct RunningApp {
    let pid: pid_t
    let activationPolicy: NSApplication.ActivationPolicy
    let ref: AppRef

    init(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        ref: AppRef
    ) {
        self.pid = pid
        self.activationPolicy = activationPolicy
        self.ref = ref
    }

    init(_ app: NSRunningApplication) {
        self.init(
            pid: app.processIdentifier,
            activationPolicy: app.activationPolicy,
            ref: AppRef(app)
        )
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
