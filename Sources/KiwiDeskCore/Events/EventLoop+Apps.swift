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
                self?.appTerminated(pid: app.processIdentifier)
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
                self?.appActivated(
                    RunningApp(app),
                    launchedAt: app.launchDate
                )
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
                self?.desktopChanged()
            }
        }
        workspaceTokens = [
            launch, terminate, activate, space, hide, unhide,
        ]

        displayWatch.start { [weak self] in
            self?.publishDisplays()
        }
        startWindowServerWakeUp()
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

    /// Descriptor-shaped, like `appHideChanged`: a test drives
    /// the unnamed pid a LaunchServices child exits with (#1785).
    func appTerminated(pid: pid_t) {
        guard Self.isProcessID(pid) else {
            retireExitedObservers()
            return
        }
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
        // (mirrors `appActivated`'s guard). Nor has an unnamed
        // pid (#1785): a child's hide is the heal's to settle.
        guard observers[pid] != nil else { return }
        reconcile(pid: pid, app: ref)
    }

    /// Closing an app's last window moves focus to a DIFFERENT
    /// app, so the closing app never reports anything. On every
    /// app switch, reconcile the app we just left. Descriptor-
    /// shaped for a test's unnamed or parent pid (#1785).
    func appActivated(_ app: RunningApp, launchedAt: Date?) {
        // A pid ≤ 0 is never an identity (#1785): an unnamed
        // announcement is its unlisted process, which the launch
        // follow and both reconciles below key on.
        let pid = process(of: app) ?? app.pid
        // Ahead of both reconciles below: a window this app shows
        // on its own activation is adopted by them, and must find
        // the #1599 launch follow already owed.
        onAppActivated(
            AppActivation(
                pid: pid,
                bundleID: app.ref.bundleID,
                launchedAt: launchedAt
            )
        )
        // The reconcile below takes this app's window snapshot
        // — no second scan at attach (#672).
        syncObservation(
            for: RunningApp(
                pid: pid,
                activationPolicy: app.activationPolicy,
                ref: app.ref
            ),
            scanWindowsAtAttach: false
        )
        if let previous = lastActivePid, previous != pid {
            reconcileOffMain(pid: previous, app: AppRef(pid: previous))
        }
        // An announcement KiwiDesk can name no process for leaves
        // the gate with no reading, which fails open (#1322).
        guard Self.isProcessID(pid) else {
            noteUnnamedActivation(app)
            return
        }
        lastActivePid = pid
        // Ignored and prohibited apps have no observer. Keep the
        // cross-app bookkeeping above, but never query their AX
        // tree merely because they became active.
        guard observers[pid] != nil else { return }
        // Several processes: the announced pid may be a sibling's.
        guard !defersToSiblingReports(pid) else {
            reconcileOffMain(pid: pid, app: app.ref)
            return
        }
        // Both reads run off the main actor (#1930): the window
        // list, and the focused window this activation reports.
        let event = ContinuousClock.now
        reconcileOffMain(pid: pid, app: app.ref)
        requestActivationFocus(pid: pid, app: app, event: event)
    }

    /// The user switched native macOS Spaces. AX only reports
    /// windows on the current space, so reconcile every app:
    /// windows of the previous space leave the layout, windows
    /// of the new space are picked up. The event goes out
    /// first so a bound profile is in place before the new
    /// space's windows are tiled.
    private func desktopChanged() {
        // Stamp before the resync so both the bulk reconcileAll and
        // any targeted reconcile racing it suppress tab coalescing
        // (departed/arrived windows tile to identical frames, #308).
        lastDesktopChange = Date()
        onEvent(.desktopChanged)
        reconcileAll()
    }

    // MARK: - Displays

    func publishDisplays() {
        DrawnMenuBars.refresh(bars: displayWatch.readDrawnMenuBars())
        let displays = NSScreen.screens.compactMap { screen in
            screen.kiwiDisplay
        }
        onEvent(.displaysChanged(displays))
    }
}

/// One app activation's facts, as `onAppActivated` reports them
/// (#1599): the launch date is what tells a launch from a switch.
struct AppActivation {
    let pid: pid_t
    let bundleID: String?
    let launchedAt: Date?
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
    /// Converts an `NSScreen` into a KiwiDesk display snapshot. Its
    /// usable area is a WindowServer round trip, so an id-only
    /// reader takes `kiwiDisplayID` (#1868).
    @MainActor var kiwiDisplay: Display? {
        guard let id = kiwiDisplayID else { return nil }
        return Display(
            id: id,
            name: localizedName,
            frame: frame,
            visibleFrame: GeometryUtils.visibleFrame(of: self)
        )
    }

    /// The screen's display id, read without a WindowServer call.
    @MainActor var kiwiDisplayID: DisplayID? {
        screenNumber.map { DisplayID($0) }
    }
}
