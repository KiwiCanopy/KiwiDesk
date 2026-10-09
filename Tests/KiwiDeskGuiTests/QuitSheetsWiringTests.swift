import Foundation
import Testing

/// Every quit path reaches `QuitSheets.clear` (#2049): the
/// `terminate(_:)` override, the class the app is launched as, the
/// power-off notification a logout's quit event follows, SIGTERM
/// in the modes a modal panel runs, and the guard predicate. A
/// test of `clear` alone cannot see a path that stopped calling it.
@Suite("Quit sheet wiring (#2049)")
struct QuitSheetsWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent("Sources/KiwiDesk/\(path)")
        )
    }

    /// The text between `start` and the next `end` after it.
    private func body(
        of text: String,
        from start: String,
        to end: String
    ) throws -> String {
        let head = try #require(text.range(of: start))
        let rest = text[head.upperBound...]
        let tail = try #require(rest.range(of: end))
        return String(rest[..<tail.upperBound])
    }

    @Test("terminate clears the sheets and stands down when refused")
    func terminateIsGated() throws {
        let app = try source("KiwiApplication.swift")
        #expect(
            app.occurrences(
                of: "final class KiwiApplication: NSApplication"
            ) == 1
        )
        let terminate = try body(
            of: app,
            from: "override func terminate(_ sender: Any?)",
            to: "super.terminate(sender)"
        )
        #expect(terminate.occurrences(of: "guard") == 1)
        #expect(terminate.occurrences(of: "QuitSheets.clear(") == 1)
        #expect(
            terminate.occurrences(
                of: "keeper: delegate as? QuitSheetKeeper"
            ) == 1
        )
        #expect(terminate.occurrences(of: "else { return }") == 1)
    }

    @Test("the app launches as KiwiApplication")
    func launchesAsTheSubclass() throws {
        let main = try source("main.swift")
        #expect(main.occurrences(of: "let app = KiwiApplication.shared") == 1)
        #expect(main.occurrences(of: "NSApplication.shared") == 0)
        #expect(main.occurrences(of: "app.delegate = delegate") == 1)
    }

    @Test("power-off clears the sheets ahead of the quit event")
    func powerOffClears() throws {
        let delegate = try source("AppDelegate.swift")
        #expect(delegate.occurrences(of: "wirePowerOffSheets()") == 1)
        let quit = try source("AppDelegate+Quit.swift")
        let observer = try body(
            of: quit,
            from: "NSWorkspace.willPowerOffNotification",
            to: "keeper: NSApp.delegate as? QuitSheetKeeper"
        )
        #expect(observer.occurrences(of: "QuitSheets.clear(") == 1)
        #expect(observer.occurrences(of: "NSApp.windows") == 1)
    }

    @Test("SIGTERM reaches terminate in the common modes")
    func sigtermRunsInCommonModes() throws {
        let delegate = try source("AppDelegate.swift")
        #expect(
            delegate.occurrences(
                of: "sigtermSource = QuitSignal.install()"
            ) == 1
        )
        #expect(delegate.occurrences(of: "makeSignalSource") == 0)
        let quit = try source("AppDelegate+Quit.swift")
        let install = try body(
            of: quit,
            from: "static func install()",
            to: "return source"
        )
        #expect(install.occurrences(of: "queue: .main") == 0)
        #expect(install.occurrences(of: "handler: deliver") == 1)
        let deliver = try body(
            of: quit,
            from: "private static func deliver()",
            to: "CFRunLoopWakeUp(main)"
        )
        #expect(
            deliver.occurrences(
                of: "CFRunLoopMode.commonModes.rawValue"
            ) == 1
        )
        #expect(deliver.occurrences(of: "NSApp.terminate(nil)") == 1)
    }

    @Test("the delegate keeps only the Settings guard")
    func keeperAsksSettings() throws {
        let quit = try source("AppDelegate+Quit.swift")
        #expect(
            quit.occurrences(
                of: "extension AppDelegate: QuitSheetKeeper"
            ) == 1
        )
        #expect(
            quit.occurrences(
                of: "dashboardIfCreated?.guardsUnsavedWork(on: window)"
            ) == 1
        )
        #expect(quit.occurrences(of: "dashboardIfCreated?.show()") == 1)
        let controller = try source(
            "Settings/SettingsWindowController.swift"
        )
        #expect(
            controller.occurrences(
                of: "window === self.window && model.quitKeepsAsking"
            ) == 1
        )
    }
}
