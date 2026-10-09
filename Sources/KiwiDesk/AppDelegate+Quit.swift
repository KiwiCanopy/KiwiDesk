import AppKit

/// The quit paths an open sheet must not block (#2049).
extension AppDelegate: QuitSheetKeeper {
    func keepsSheet(on window: NSWindow) -> Bool {
        dashboardIfCreated?.guardsUnsavedWork(on: window) ?? false
    }

    func quitRefused() {
        dashboardIfCreated?.show()
    }

    /// A logout's or restart's quit event is refused by AppKit
    /// before `terminate(_:)` runs while a non-alert sheet is up,
    /// so the sheets clear on the notification that precedes it.
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
}

/// SIGTERM into AppKit's termination flow. Delivered in the main
/// run loop's COMMON modes: the main queue does not drain inside
/// a modal session (an open or save panel), so a main-queue
/// handler waited for the panel to close (#2049).
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
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        CFRunLoopWakeUp(main)
    }
}
