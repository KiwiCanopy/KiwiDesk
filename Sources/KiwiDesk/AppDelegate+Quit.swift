import AppKit

/// The quit paths (#2049): an open sheet never blocks one, and
/// unsaved Settings edits ask before any quit that can wait.
extension AppDelegate: QuitQuestionHost {
    /// Every quit AppKit asks about — Quit, Install and Relaunch,
    /// another app's quit event, a logout or restart — while
    /// Settings is open with unsaved edits is CANCELLED and the
    /// question shown; its answer quits again. Never
    /// `.terminateLater`: that runs the run loop in the modal-panel
    /// mode, where other apps' AX notifications are not delivered,
    /// so tiling would go deaf while the question waits.
    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard let dashboard = dashboardIfCreated else {
            return .terminateNow
        }
        if dashboard.takeQuitAnswer() { return .terminateNow }
        guard dashboard.quitAsksAboutDraft else { return .terminateNow }
        dashboard.askBeforeQuit {
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return .terminateCancel
    }

    func frontPendingQuestion() -> Bool {
        dashboardIfCreated?.frontPendingQuestion() ?? false
    }

    /// A logout's or restart's quit event is refused by AppKit
    /// before `terminate(_:)` runs while a non-alert sheet is up,
    /// so the sheets close on the notification that precedes it.
    func wirePowerOffSheets() {
        powerOffObserver = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.willPowerOffNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    _ = QuitSheets.clearOwnWindows()
                }
            }
    }

    /// SIGTERM cannot wait for an answer: the draft goes first,
    /// so the quit has nothing to ask.
    func quitDiscardingDraft() {
        dashboardIfCreated?.dropDraftForQuit()
        NSApp.terminate(nil)
    }
}

/// SIGTERM into AppKit's termination flow, discarding unsaved
/// Settings edits. Delivered in the main run loop's COMMON modes:
/// the main queue does not drain inside a modal session (an open
/// or save panel), so a main-queue handler waited for the panel to
/// close (#2049).
enum QuitSignal {
    static func install() -> DispatchSourceSignal {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(
            signal: SIGTERM,
            queue: .global(qos: .userInitiated)
        )
        source.setEventHandler(handler: deliver)
        source.resume()
        return source
    }

    @Sendable private static func deliver() {
        let main = CFRunLoopGetMain()
        CFRunLoopPerformBlock(main, CFRunLoopMode.commonModes.rawValue) {
            MainActor.assumeIsolated {
                guard let delegate = NSApp.delegate as? AppDelegate else {
                    return NSApp.terminate(nil)
                }
                delegate.quitDiscardingDraft()
            }
        }
        CFRunLoopWakeUp(main)
    }
}
