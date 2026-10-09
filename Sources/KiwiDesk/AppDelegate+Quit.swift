import AppKit

/// The quit paths (#2049): an open sheet never blocks one, and
/// unsaved Settings edits ask before any quit that can wait.
extension AppDelegate {
    /// Every quit AppKit asks about — Quit, Install and Relaunch,
    /// another app's quit event, a logout or restart — asks Save /
    /// Discard / Cancel while Settings is open with unsaved edits.
    /// A SIGTERM cannot wait, so it discards.
    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        if (sender as? KiwiApplication)?.quitDiscardsDraft == true {
            return .terminateNow
        }
        guard let dashboard = dashboardIfCreated,
            dashboard.quitAsksAboutDraft
        else { return .terminateNow }
        dashboard.askBeforeQuit { proceed in
            NSApp.reply(toApplicationShouldTerminate: proceed)
        }
        return .terminateLater
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
                    QuitSheets.clearOwnWindows()
                }
            }
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
                guard let app = NSApp as? KiwiApplication else {
                    return NSApp.terminate(nil)
                }
                app.terminateDiscardingDraft()
            }
        }
        CFRunLoopWakeUp(main)
    }
}
