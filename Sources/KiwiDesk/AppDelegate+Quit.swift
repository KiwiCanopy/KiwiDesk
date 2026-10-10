import AppKit

/// The quit paths (#2049): an open sheet never blocks one, and
/// unsaved Settings edits ask before any quit that can wait.
extension AppDelegate: QuitQuestionHost {
    /// Every quit AppKit asks about — Quit, Install and Relaunch,
    /// another app's quit event — while Settings is open with
    /// unsaved edits is CANCELLED and the question shown; its
    /// answer quits again. A logout, restart or shut down discards
    /// them instead: macOS asks a menu-bar app only past its point
    /// of no return, so a cancel is ignored (#2135). Never
    /// `.terminateLater`: that runs the run loop in the modal-panel
    /// mode, where other apps' AX notifications are not delivered,
    /// so tiling would go deaf while the question waits.
    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard let dashboard = dashboardIfCreated else {
            return .terminateNow
        }
        if QuitReason.isPowerOff(
            NSAppleEventManager.shared().currentAppleEvent
        ) {
            dashboard.dropDraftForQuit()
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
    /// so the sheets close on the notification that precedes it —
    /// and unsaved Settings edits go with them, since the quit
    /// cannot wait for an answer (#2135).
    func wirePowerOffSheets() {
        powerOffObserver = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.willPowerOffNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.dashboardIfCreated?.dropDraftForQuit()
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

/// Whether a quit event is macOS logging out, restarting or
/// shutting down (#2135): its `kAEQuitReason` parameter.
enum QuitReason {
    static let powerOff: Set<OSType> = [
        OSType(kAELogOut),
        OSType(kAEReallyLogOut),
        OSType(kAEShowRestartDialog),
        OSType(kAEShowShutdownDialog),
        OSType(kAERestart),
        OSType(kAEShutDown),
    ]

    static func isPowerOff(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event,
            event.eventClass == AEEventClass(kCoreEventClass),
            event.eventID == AEEventID(kAEQuitApplication),
            let reason = event.paramDescriptor(
                forKeyword: AEKeyword(kAEQuitReason)
            )
        else { return false }
        return powerOff.contains(reason.enumCodeValue)
            || powerOff.contains(reason.typeCodeValue)
    }
}
