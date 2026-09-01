import AppKit
import ApplicationServices

/// Per-app AX observer ownership and rule-driven attachment.
extension EventLoop {
    /// Reconciles app-level observation with the current ignore
    /// rules. An ignored app has no AX observer, no enhanced-UI
    /// flag, and no tracked windows.
    ///
    /// `scanWindowsAtAttach: false` is for callers that run a
    /// `reconcile` of the same app on the same turn: the
    /// reconcile takes the one window snapshot, so scanning at
    /// attach too would read every window list twice (#672).
    /// Safe by the same promise as the boot prefilter — the
    /// following reconcile warms and tracks whatever attach
    /// skipped (StartupWarmupSkipTests, #662). Under
    /// `reconcileAll`'s census gate (#1037) that reconcile is
    /// the first pass to REACH the app, which for one showing
    /// nothing is not this turn's.
    func syncObservation(
        for app: RunningApp,
        scanWindowsAtAttach: Bool
    ) {
        let isIgnored = shouldIgnoreApp(
            bundleID: app.ref.bundleID
        )
        guard
            Self.shouldAttach(
                pid: app.pid,
                activationPolicy: app.activationPolicy,
                isIgnored: isIgnored
            )
        else {
            detach(pid: app.pid, restoreEnhancedUI: true)
            return
        }
        attach(
            pid: app.pid,
            activationPolicy: app.activationPolicy,
            ref: app.ref,
            scanWindowsAtAttach: scanWindowsAtAttach
        )
    }

    /// Attaches to regular and accessory apps from launch. The
    /// observer is installed before the initial window snapshot,
    /// closing the gap in which an accessory app can create its
    /// first window (#177).
    ///
    /// `scanWindowsAtAttach: false` skips the expensive AX
    /// window query and EUI/MAI warmup here, for one of two
    /// reasons that share one safety argument: the boot scan's
    /// WindowServer prefilter says the app is windowless, or
    /// the caller reconciles this app on the same turn (#672
    /// scan dedup). Either way the AXObserver still fires for
    /// future window creation and a following reconcile warms
    /// and tracks what was skipped — the promise
    /// `StartupWarmupSkipTests` pins (#662). No default: every
    /// caller states its answer.
    func attach(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        ref: AppRef,
        scanWindowsAtAttach: Bool
    ) {
        // Nothing attaches before `start()` (#672): loadConfig's
        // pre-start `reconcileAll()` used to reach here and
        // attach every app with the eager default above, which
        // made the boot scan's prefilter test nothing — every
        // app was already attached and warmed by the time
        // `start()` ran.
        guard isRunning else { return }
        guard observers[pid] == nil else { return }
        guard
            Self.shouldAttach(
                pid: pid,
                activationPolicy: activationPolicy,
                isIgnored: shouldIgnoreApp(
                    bundleID: ref.bundleID
                )
            )
        else { return }
        // Per-app timing (#672): every AX round trip below can
        // block on an unresponsive app, and the boot scan runs
        // them serially — so each attach is an interval, and a
        // slow one logs the app's name for field reports.
        let name = ref.bundleID ?? ref.name
        let signposter = BootSignpost.signposter
        let span = signposter.beginInterval(
            "attach",
            id: signposter.makeSignpostID(),
            "\(name, privacy: .public)"
        )
        let begin = ContinuousClock.now
        defer {
            signposter.endInterval("attach", span)
            let ms = begin.duration(to: .now).wholeMilliseconds
            if ms >= BootSignpost.slowSpanMs {
                onLog("slow attach: \(name) took \(ms)ms")
            }
        }
        // Opened BEFORE the observer install, not after: an app
        // the prefilter calls windowless returns below without
        // ever reaching the window query, so a budget opened
        // there sees none of its cost — and the measured outlier
        // spends all 4004 ms of it right here, in
        // `AXObserverCreate` plus the notification adds, four
        // calls each hitting the ~1 s messaging timeout (owner's
        // device log, 2026-08-12).
        let budget = openAppBudget()
        guard let observer = makeObserver(pid)
        else { return }

        observer.onNotification = { [weak self] note, element in
            self?.handle(note, element, pid: pid, app: ref)
        }
        observers[pid] = observer
        // Attached either way — the observer is installed, so the
        // app's windows still arrive by event — but it stops
        // paying for boot work it has already proven it cannot
        // answer in time.
        //
        // This deliberately also defers an app the prefilter
        // called windowless, which then earns a completing
        // reconcile it would otherwise not have needed (review,
        // 2026-08-12). Kept, because the alternative abandons it:
        // the skip list means its SWEEP is skipped too, so #662's
        // warm-on-reconcile promise is no longer the thing that
        // covers it. The cost is bought off by when the drain
        // runs, not by dropping the completion —
        // `KiwiCore.deferredAppPause` carries that argument.
        guard !budget.isSpent else {
            deferBootWork(
                pid: pid,
                ref: ref,
                spentMs: budget.spentMs
            )
            return
        }

        // Skip the slow AX window query and warmup when asked
        // (windowless per the prefilter, or a same-turn
        // reconcile follows) — the observer above still catches
        // future window creation, and a following reconcile
        // re-warms (StartupWarmupSkipTests, #662).
        guard scanWindowsAtAttach else { return }

        // A hidden app's windows are listed by AX and on screen
        // nowhere (`reconcile` carries the argument, #913), so
        // adopting them here would tile what the user cannot
        // see — boot's way into the same defect. The observer
        // above stays installed, and the unhide reconcile
        // adopts them.
        //
        // Warmed on the way out, though. #662's promise is that
        // a following reconcile warms whatever attach skipped,
        // and the hidden reconcile returns before its warm too
        // — so an app hidden across boot would meet its first
        // unhide with a cold AX tree, and an Electron app with
        // a cold tree answers an EMPTY window list. That is
        // Discord's exact shape, and it would put the window
        // back on the census heal's latency instead of the
        // gesture. An accessory app is left to that reconcile:
        // the warm below needs the window list to decide it is
        // worth warming at all, and this path is refusing to
        // read that list.
        if appIsHidden(pid) {
            if activationPolicy == .regular {
                warmAccessibilityTree(pid: pid)
            }
            return
        }

        // Every call below can block for a whole AX messaging
        // timeout on an unresponsive app, and boot pays them
        // serially — so a chunked pass drops what is left of this
        // app's work past its budget and completes it after boot
        // (#803). Inert outside a queued boot step.
        let windows = axWindows(pid)
        if activationPolicy == .regular
            || windows.contains(where: Self.isStandardWindow)
        {
            guard !budget.isSpent else {
                deferBootWork(
                    pid: pid,
                    ref: ref,
                    spentMs: budget.spentMs
                )
                return
            }
            warmAccessibilityTree(pid: pid)
        }
        let displayBounds = FloatDetection.activeDisplayBounds()
        for element in windows {
            guard !budget.isSpent else {
                deferBootWork(
                    pid: pid,
                    ref: ref,
                    spentMs: budget.spentMs
                )
                return
            }
            track(
                element,
                pid: pid,
                app: ref,
                displayBounds: displayBounds
            )
        }
    }

    nonisolated static func isStandardWindow(
        _ element: AXUIElement
    ) -> Bool {
        AXHelper.role(of: element) == kAXWindowRole
            && AXHelper.subrole(of: element)
                == kAXStandardWindowSubrole
    }

    /// Makes an app's AX tree materialize so its windows show up in
    /// `kAXWindowsAttribute`, by whichever mechanism the app honors:
    /// `AXEnhancedUserInterface` for Electron/WebKit, or
    /// `AXManualAccessibility` for Chromium-family browsers (which
    /// never answer the EUI read). Idempotent; called at attach and
    /// re-tried on later reconciles for cold apps.
    func warmAccessibilityTree(pid: pid_t) {
        guard enhancedUIBaselines[pid] == nil else { return }
        guard let baseline = readEnhancedUI(pid)
        else {
            // The app does not answer the EUI read. Chromium-family
            // browsers (Chrome, Brave, Edge, Arc, …) behave this way
            // and gate their AX tree behind AXManualAccessibility, so
            // the EUI warm-up below can never reach them and their
            // windows never appear in kAXWindowsAttribute. The *set* is
            // what materializes the tree; the ordinary reconcile
            // window re-scan then finds the windows — so set it once
            // (the attribute sticks) rather than re-writing on every
            // reconcile, since the EUI read that would record a
            // baseline stays nil for a Chromium app forever (#360).
            guard manualAXApplied.insert(pid).inserted else { return }
            writeManualAX(pid, true)
            return
        }
        enhancedUIBaselines[pid] = baseline
        guard !baseline else { return }
        // Keep Electron/WebKit AX trees warm (see AGENTS.md).
        writeEnhancedUI(pid, true)
    }

    func detach(
        pid: pid_t,
        restoreEnhancedUI: Bool
    ) {
        observers.removeValue(forKey: pid)?.invalidate()
        if let baseline = enhancedUIBaselines.removeValue(
            forKey: pid
        ), restoreEnhancedUI, !baseline {
            writeEnhancedUI(pid, false)
        }
        // AXManualAccessibility is left set on the app (an eager AX
        // tree is what a managed app wants); only forget the pid so a
        // re-attach re-applies the warm-up (#360).
        manualAXApplied.remove(pid)
        // The heal ledgers are per-app state too (#675): a
        // relaunch reusing the pid starts with a fresh retry
        // budget and an unquieted gate.
        healQuiet[pid] = nil
        transientRetried[pid] = nil
        pendingRetrack.remove(pid)
        for id in Array(elements[pid, default: [:]].keys) {
            releaseWindowRegistration(id, pid: pid)
            onEvent(.windowDestroyed(id, wasMinimized: false))
        }
        elements[pid] = nil
    }
}
