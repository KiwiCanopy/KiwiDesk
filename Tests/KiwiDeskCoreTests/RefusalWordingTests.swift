import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A refusal states the rule that forbids the act (#3037): each arm
/// that used to share one sentence says its own, and a Lua call's
/// log line carries the values the sentence no longer repeats.
@Suite("Refusal wording (#3037)", .serialized)
@MainActor
struct RefusalWordingTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-refusal-\(UUID().uuidString)"
                )
        )
    }

    private func track(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t = 1,
        change: (inout ManagedWindow) -> Void = { _ in }
    ) {
        var window = ManagedWindow(
            id: WindowID(raw),
            pid: pid,
            appName: "App",
            title: "W\(raw)"
        )
        change(&window)
        core.state.apply(.windowCreated(window))
    }

    private func away(_ raw: UInt32) -> AwayWindow {
        AwayWindow(
            id: WindowID(raw),
            pid: 4242,
            appName: "App",
            appBundleID: "com.example.app",
            title: "Elsewhere",
            nativeSpace: 999_999
        )
    }

    // MARK: - The foreground preflight

    @Test("an app in front is said apart from an untracked one")
    func preflightNamesItsArm() {
        let core = makeCore()
        track(core, 1)
        core.frontmostPIDProvider = { 999 }
        #expect(
            core.execute("make_floating").error
                == "another app is in front of the focused window"
        )
        core.frontmostPIDProvider = { 1 }
        #expect(
            core.execute("make_floating").error
                == "KiwiDesk is not tracking the focused window's app"
        )
        core.frontmostPIDProvider = { nil }
        #expect(
            core.execute("make_floating").error
                == "the frontmost app is unknown"
        )
    }

    @Test("an ignored panel in front says so")
    func preflightNamesThePanel() throws {
        let core = makeCore()
        let pid = getpid()
        track(core, 1, pid: pid)
        let observer = try #require(AXApplicationObserver(pid: pid))
        core.eventLoop.observers[pid] = observer
        core.frontmostPIDProvider = { pid }
        core.ignoredPanel.active.insert(pid)
        #expect(
            core.execute("make_floating").error
                == "a panel KiwiDesk ignores is in front"
        )
    }

    // MARK: - A named window

    @Test("a window on another Desktop is not called unknown")
    func awayIsNotUnknown() {
        let core = makeCore()
        core.state.awayWindows[WindowID(9)] = away(9)
        #expect(
            core.execute("focus_window", args: [.number(9)]).error
                == "this command cannot reach window 9 on another Desktop"
        )
        #expect(
            core.execute("focus_window", args: [.number(77)]).error
                == "unknown window: 77"
        )
    }

    @Test("a window on a full-screen Space is said apart")
    func awayOnFullScreenSpace() {
        let core = makeCore()
        core.state.awayWindows[WindowID(9)] = away(9)
        core.desktopMemory.readDesktops = {
            DesktopSnapshot(
                authority: nil,
                mainUUID: nil,
                mainCurrentSpace: nil,
                currentSpaces: [:],
                spaces: [
                    NativeSpace(
                        id: 999_999,
                        displayUUID: "A",
                        isCurrent: false,
                        isUser: false
                    )
                ]
            )
        }
        #expect(
            core.execute("focus_window", args: [.number(9)]).error
                == "this command cannot reach full-screen window 9"
        )
    }

    // MARK: - The pocket

    @Test("what cannot be pocketed says what it is")
    func cannotPocketNamesTheKind() {
        let core = makeCore()
        track(core, 1) { $0.isFullscreen = true }
        track(core, 2) { $0.isTransientOverlay = true }
        #expect(
            core.execute("pocket", args: [.number(1)]).error
                == "a full-screen window cannot be pocketed"
        )
        #expect(
            core.execute("pocket", args: [.number(2)]).error
                == "a panel or popup cannot be pocketed"
        )
    }

    @Test("a failed take-out tells a hidden app from no Space")
    func takeOutNamesItsArm() {
        let core = makeCore()
        track(core, 1)
        #expect(
            core.takeOutFailure(WindowID(1))
                == "no active Space to take the pocket window out onto"
        )
        #expect(
            core.takeOutFailure(WindowID(99))
                == KiwiCore.pocketAppHidden
        )
    }

    @Test("pocket on a window its app's hiding took says so")
    func pocketAnswersHidden() {
        let core = makeCore()
        let id = WindowID(1)
        track(core, 1, pid: getpid())
        #expect(core.execute("pocket", args: [.number(1)]).isSuccess)
        core.state.windows.remove(id)
        #expect(core.execute("pocket").error == KiwiCore.pocketAppHidden)
    }

    @Test("an out window its app's hiding took says so")
    func outSlotAnswersHidden() {
        let core = makeCore()
        let id = WindowID(1)
        track(core, 1, pid: getpid())
        let marked = core.state.markPocketWindow(id)
        #expect(marked)
        core.state.windows.remove(id)
        #expect(core.execute("pocket").error == KiwiCore.pocketAppHidden)
    }

    @Test("every take-out door names no active Space")
    func takeOutWithNoSpace() {
        let core = makeCore()
        let id = WindowID(1)
        track(core, 1)
        let marked = core.state.markPocketWindow(
            id,
            owner: "com.example.app"
        )
        #expect(marked)
        core.state.pocket[0].phase = .pocketed
        core.state.workspaces = WorkspaceManager()
        let noSpace = "no active Space to take the pocket window out onto"
        #expect(
            core.execute("focus_window", args: [.number(1)]).error == noSpace
        )
        #expect(
            core.execute("pocket_app", args: [.string("com.example.app")])
                .error == noSpace
        )
    }

    @Test("an app's key on a slot with no process says it is not found")
    func keyedSlotNotFound() {
        let core = makeCore()
        let id = WindowID(1)
        track(core, 1)
        let marked = core.state.markPocketWindow(
            id,
            owner: "com.example.app"
        )
        #expect(marked)
        core.state.pocket[0].pid = nil
        core.state.windows.remove(id)
        #expect(
            core.execute("pocket_app", args: [.string("com.example.app")])
                .error == "the pocket window's app cannot be found"
        )
    }

    // MARK: - Maximize

    @Test("maximize says only a tiled window can")
    func maximizeNamesTheRule() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        track(core, 1) { $0.isFloating = true }
        #expect(
            core.execute("toggle_maximized").error
                == "only a tiled window can be maximized"
        )
    }

    // MARK: - The pills

    @Test("each new pill says its own sentence")
    func pillSentences() {
        LocalizationManager.shared.select("en")
        let sentences: [(WindowActionRefusal, String)] = [
            (
                .cannotMoveHereFullScreen,
                "A full-screen window can't be moved here"
            ),
            (.cannotSwapPocketed, "A pocketed window can't be swapped"),
            (.cannotSwapUnfiled, "A window in no Space can't be swapped"),
            (.cannotSwapMinimized, "A minimized window can't be swapped"),
            (.cannotSwapHiddenApp, "A hidden app's window can't be swapped"),
            (
                .cannotSwapHiddenDesktop,
                "A window on a hidden Desktop can't be swapped"
            ),
            (.cannotSwapGone, "That window is no longer here"),
        ]
        for (refusal, sentence) in sentences {
            #expect(refusal.sentence == sentence)
        }
        #expect(
            PocketRefusal.markedElsewhereSentence
                == "The Pocket takes one window. "
                + "Set it to Several windows to add more."
        )
    }

    // MARK: - KiwiHub's rows no verb can see

    @Test("Swap here names what the row is")
    func swapHereNamesTheRow() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        track(core, 1)
        core.state.awayWindows[WindowID(9)] = away(9)
        core.state.minimizeOrder.append(
            .init(
                id: WindowID(8),
                pid: 4242,
                bundleID: "com.example.app",
                app: "App",
                title: "Folded"
            )
        )
        let reasons: [(JumpEntry.Target, WindowActionRefusal)] = [
            (.window(WindowID(9)), .cannotSwapHiddenDesktop),
            (.window(WindowID(8)), .cannotSwapMinimized),
            (.hiddenApp(4242), .cannotSwapHiddenApp),
            (.window(WindowID(77)), .cannotSwapGone),
        ]
        for (target, refusal) in reasons {
            logs = []
            core.swapHere(target)
            #expect(
                logs.contains { $0.contains(refusal.logReason) },
                "\(target)"
            )
        }
    }

    // MARK: - The Lua log line

    @Test("a failed Lua call logs the values it passed")
    func luaLogsTheValues() throws {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        try FileManager.default.createDirectory(
            at: core.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "KiwiDesk.focus_window(77)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(
            logs.contains("focus_window [77]: unknown window: 77"),
            "\(logs)"
        )
    }

    @Test("the logged call stays short and leaves a bare call bare")
    func loggedCallShape() {
        #expect(KiwiCore.loggedCall("focus", []) == "focus")
        #expect(
            KiwiCore.loggedCall("swap", [.string("left"), .number(2)])
                == "swap [\"left\",2]"
        )
        let long = String(repeating: "x", count: 500)
        #expect(
            KiwiCore.loggedCall("set", [.string(long)]).count
                == "set ".count + 200
        )
        #expect(
            KiwiCore.loggedCall(
                "put",
                [.object(["b": .string("/x"), "a": .number(1)])]
            ) == "put [{\"a\":1,\"b\":\"/x\"}]"
        )
    }
}
