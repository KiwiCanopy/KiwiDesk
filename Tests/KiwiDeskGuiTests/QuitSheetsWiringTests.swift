import Foundation
import Testing

/// Every quit and close path reaches its door (#2049): the
/// `terminate(_:)` override and the class the app is launched as,
/// the power-off notification a logout's quit event follows,
/// SIGTERM in the modes a modal panel runs and without asking,
/// `applicationShouldTerminate`'s question, every close path's,
/// and the dialog and naming prompt that answer it. A test of the
/// doors alone cannot see a path that stopped calling them.
@Suite("Quit and close wiring (#2049)")
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

    @Test("terminate closes the sheets before AppKit decides")
    func terminateClearsFirst() throws {
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
        #expect(
            terminate.occurrences(of: "QuitSheets.clearOwnWindows()") == 1
        )
        let sheets = try source("QuitSheets.swift")
        let door = try body(
            of: sheets,
            from: "static func clearOwnWindows()",
            to: "}"
        )
        #expect(door.occurrences(of: "clear(NSApp.windows)") == 1)
    }

    @Test("the app launches as KiwiApplication")
    func launchesAsTheSubclass() throws {
        let main = try source("main.swift")
        #expect(
            main.occurrences(of: "let app = KiwiApplication.shared") == 1
        )
        #expect(main.occurrences(of: "NSApplication.shared") == 0)
        #expect(main.occurrences(of: "app.delegate = delegate") == 1)
    }

    @Test("power-off closes the sheets ahead of the quit event")
    func powerOffClears() throws {
        let delegate = try source("AppDelegate.swift")
        #expect(delegate.occurrences(of: "wirePowerOffSheets()") == 1)
        let quit = try source("AppDelegate+Quit.swift")
        let observer = try body(
            of: quit,
            from: "NSWorkspace.willPowerOffNotification",
            to: "QuitSheets.clearOwnWindows()"
        )
        #expect(observer.occurrences(of: "queue: .main") == 1)
        #expect(
            quit.occurrences(of: "QuitSheets.clearOwnWindows()") == 1
        )
    }

    @Test("SIGTERM quits in the common modes and asks nothing")
    func sigtermDiscards() throws {
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
        #expect(
            install.occurrences(
                of: "queue: .global(qos: .userInitiated)"
            ) == 1
        )
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
        #expect(
            deliver.occurrences(of: "app.terminateDiscardingDraft()") == 1
        )
        let app = try source("KiwiApplication.swift")
        let discarding = try body(
            of: app,
            from: "func terminateDiscardingDraft()",
            to: "terminate(nil)"
        )
        #expect(
            discarding.occurrences(of: "quitDiscardsDraft = true") == 1
        )
    }

    @Test("a quit AppKit asks about waits for the draft question")
    func shouldTerminateAsks() throws {
        let quit = try source("AppDelegate+Quit.swift")
        let ask = try body(
            of: quit,
            from: "func applicationShouldTerminate(",
            to: "return .terminateLater"
        )
        for needle in [
            "quitDiscardsDraft == true",
            "dashboard.quitAsksAboutDraft",
            "dashboard.askBeforeQuit",
            "NSApp.reply(toApplicationShouldTerminate: proceed)",
        ] {
            #expect(ask.occurrences(of: needle) == 1, "\(needle)")
        }
        let controller = try source(
            "Settings/SettingsWindowController.swift"
        )
        let asks = try body(
            of: controller,
            from: "var quitAsksAboutDraft: Bool",
            to: "return model.isDirty"
        )
        #expect(
            asks.occurrences(
                of: "window.isVisible || window.isMiniaturized"
            ) == 1
        )
        let before = try body(
            of: controller,
            from: "func askBeforeQuit(",
            to: "cancel: { reply(false) }"
        )
        #expect(before.occurrences(of: "show()") == 1)
        #expect(before.occurrences(of: "model.leavingDraft(") == 1)
        #expect(before.occurrences(of: ".quit,") == 1)
    }

    @Test("every close path asks, and a close drops the draft")
    func closeAsks() throws {
        let controller = try source(
            "Settings/SettingsWindowController.swift"
        )
        let should = try body(
            of: controller,
            from: "func windowShouldClose(_ sender: NSWindow) -> Bool",
            to: "return false"
        )
        #expect(should.occurrences(of: "guard model.isDirty") == 1)
        #expect(should.occurrences(of: "model.leavingDraft(") == 1)
        #expect(should.occurrences(of: ".close,") == 1)
        let willClose = try body(
            of: controller,
            from: "func windowWillClose(",
            to: "model.settingsClosed()"
        )
        #expect(
            willClose.occurrences(of: "if model.isDirty { model.revert() }")
                == 1
        )
    }

    @Test("the dialog and the naming prompt answer the leave")
    func dialogAnswers() throws {
        let host = try source("Settings/DiscardConfirm.swift")
        #expect(
            host.occurrences(
                of: "if !shown { model.discardDialogDismissed() }"
            ) == 1
        )
        #expect(host.occurrences(of: "leaveActions(pending)") == 1)
        let actions = try source("Settings/DiscardConfirm+Leave.swift")
        for needle in [
            "model.saveAndLeave(pending)",
            ".keyboardShortcut(.defaultAction)",
            ".keyboardShortcut(\"d\")",
            "model.cancelPendingDiscard()",
        ] {
            #expect(actions.occurrences(of: needle) == 1, "\(needle)")
        }
        let footer = try source("Settings/SettingsFooter.swift")
        #expect(
            footer.occurrences(of: "onChange(of: model.leaveNamingRequested)")
                == 1
        )
        #expect(footer.occurrences(of: "model.namingEnded()") == 2)
    }
}
