import AppKit
import ApplicationServices

/// Start/stop lifecycle. Split from `EventLoop.swift` for file
/// size (§2); the attach path it drives lives in
/// `EventLoop+AppObservation.swift`.
extension EventLoop {
    // Starting observation is `beginScan()` plus the chunks its
    // driver runs (`EventLoop+BootScan`, #801) — there is no
    // single-call start any more, because the scan holds the run
    // loop the menu bar needs and one call cannot hand it back.
    // The windowless-app prefilter promise survives the split
    // unchanged; `beginScan` states it.

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
            writeEnhancedUI(pid, false)
        }
        observers = [:]
        elements = [:]
        enhancedUIBaselines = [:]
        manualAXApplied = []
        detectedFloating = [:]
        detectedFullscreen = [:]
        ignorePending = []
        trackedFrames = [:]
        tabCarriers = []
        healQuiet = [:]
        transientRetried = [:]
        pendingRetrack = []
        // A pass in flight dies with the loop: its queue names
        // apps this run attached, and its deferred ledger names
        // work a later `start()` re-queues from scratch. The
        // interval is closed rather than dropped so a stopped
        // boot leaves no open span in Instruments.
        if let interval = bootScan.interval {
            BootSignpost.signposter.endInterval(
                bootScan.pass.signpostName,
                interval
            )
        }
        // The clock seam outlives the pass: it is injected once
        // per test, and a stop that restored the live default
        // would silently un-fake the next pass's budgets.
        let clock = bootScan.now
        bootScan = BootScanState()
        bootScan.now = clock
    }
}
