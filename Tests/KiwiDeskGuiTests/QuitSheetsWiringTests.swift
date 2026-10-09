import Foundation
import Testing

/// Every quit and close path reaches its door (#2049): the
/// `terminate(_:)` override and the class the app is launched as,
/// the power-off notification a logout's quit event follows,
/// SIGTERM in the modes a modal panel runs and without asking,
/// `applicationShouldTerminate`'s cancel-and-ask, every close
/// path's question, and the dialog, naming prompt and one primary
/// Save that answer it. A test of the doors alone cannot see a
/// path that stopped calling them.
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

    private func expectOnce(_ needles: [String], in text: String) {
        for needle in needles {
            #expect(text.occurrences(of: needle) == 1, "\(needle)")
        }
    }

    @Test("terminate takes the one door, which fronts a waiting question")
    func terminateTakesTheDoor() throws {
        let app = try source("KiwiApplication.swift")
        expectOnce(
            [
                "final class KiwiApplication: NSApplication",
                "guard QuitSheets.clearOwnWindows() else { return }",
                "super.terminate(sender)",
            ],
            in: app
        )
        let sheets = try source("QuitSheets.swift")
        let door = try body(
            of: sheets,
            from: "static func clearOwnWindows() -> Bool",
            to: "return true"
        )
        expectOnce(
            [
                "host?.frontPendingQuestion() == true { return false }",
                "clear(NSApp.windows)",
            ],
            in: door
        )
    }

    @Test("the app launches as KiwiApplication")
    func launchesAsTheSubclass() throws {
        let main = try source("main.swift")
        expectOnce(
            ["let app = KiwiApplication.shared", "app.delegate = delegate"],
            in: main
        )
        #expect(main.occurrences(of: "NSApplication.shared") == 0)
    }

    @Test("power-off takes the door ahead of the quit event")
    func powerOffTakesTheDoor() throws {
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

    @Test("SIGTERM drops the draft, then quits in the common modes")
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
        expectOnce(
            [
                "queue: .global(qos: .userInitiated)",
                "handler: deliver",
            ],
            in: install
        )
        let deliver = try body(
            of: quit,
            from: "private static func deliver()",
            to: "CFRunLoopWakeUp(main)"
        )
        expectOnce(
            [
                "CFRunLoopMode.commonModes.rawValue",
                "delegate.quitDiscardingDraft()",
            ],
            in: deliver
        )
        let discarding = try body(
            of: quit,
            from: "func quitDiscardingDraft()",
            to: "NSApp.terminate(nil)"
        )
        #expect(
            discarding.occurrences(
                of: "dashboardIfCreated?.dropDraftForQuit()"
            ) == 1
        )
    }

    @Test("a quit with unsaved edits is cancelled and asked again")
    func shouldTerminateCancelsAndAsks() throws {
        let quit = try source("AppDelegate+Quit.swift")
        let ask = try body(
            of: quit,
            from: "func applicationShouldTerminate(",
            to: "return .terminateCancel"
        )
        expectOnce(
            [
                "if dashboard.takeQuitAnswer() { return .terminateNow }",
                "guard dashboard.quitAsksAboutDraft",
                "dashboard.askBeforeQuit",
                "NSApp.terminate(nil)",
            ],
            in: ask
        )
        #expect(quit.occurrences(of: "terminateLater") == 0)
        let controller = try source(
            "Settings/SettingsWindowController.swift"
        )
        expectOnce(
            [
                "window.map { $0.isVisible || $0.isMiniaturized }",
                "var quitAsksAboutDraft: Bool { isShown && model.isDirty }",
                "model.prepareToShow(windowShown: isShown)",
                "model.askBeforeQuit(terminate: terminate)",
                "guard model.draftLeave != nil else { return false }",
            ],
            in: controller
        )
        let before = try body(
            of: controller,
            from: "func askBeforeQuit(",
            to: "model.askBeforeQuit(terminate: terminate)"
        )
        #expect(before.occurrences(of: "show()") == 1)
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
        expectOnce(
            ["guard model.isDirty", "model.leavingDraft(", ".close,"],
            in: should
        )
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

    @Test("the dialog and naming prompt settle the leave")
    func dialogAnswers() throws {
        let host = try source("Settings/DiscardConfirm.swift")
        expectOnce(
            [
                "let shownID = model.pendingDiscard?.id",
                "if !shown { model.discardDialogDismissed(shownID) }",
                "leaveActions(pending)",
            ],
            in: host
        )
        let actions = try source("Settings/DiscardConfirm+Leave.swift")
        expectOnce(
            [
                "model.saveAndLeave(pending)",
                ".keyboardShortcut(.defaultAction)",
                ".keyboardShortcut(\"d\")",
                "model.cancelPendingDiscard()",
                "pending.saveLabel == nil ? .defaultAction : nil",
            ],
            in: actions
        )
        let footer = try source("Settings/SettingsFooter.swift")
        expectOnce(
            [
                "onChange(of: model.newProfileNamingRequested)",
                "if was && !now { model.namingEnded() }",
                "if namingNewProfile { model.namingEnded() }",
            ],
            in: footer
        )
        #expect(footer.occurrences(of: "model.namingEnded()") == 2)
    }

    @Test("the footer, the question and Fit Gaps share one Save")
    func onePrimarySave() throws {
        let slots = try source("Settings/SettingsFooter+Slots.swift")
        expectOnce(
            [
                "Button(model.primarySaveLabel) { "
                    + "model.performPrimarySave() }",
                ".disabled(!model.primarySaveEnabled)",
                ".help(model.primarySaveBlockedReason ?? \"\")",
            ],
            in: slots
        )
        let leave = try source("Settings/SettingsModel+Leave.swift")
        expectOnce(
            [
                "let canSave = primarySaveEnabled",
                "saveLabel: canSave ? primarySaveLabel : nil",
                "performPrimarySave()",
            ],
            in: leave
        )
        // Fit Gaps names the verb by the same classifier; its
        // labels stay literal `L(...)` arguments, which #818's
        // `InterpolatedLabelTests` reads.
        let fit = try source(
            "Settings/Components/GapsAndBorders/FitGapsAction.swift"
        )
        #expect(
            fit.occurrences(of: "switch model.primarySaveAction") == 1
        )
    }
}
