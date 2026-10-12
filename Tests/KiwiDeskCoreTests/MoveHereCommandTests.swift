import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_here`'s command flows (#1513 ▸ Ruling): repeat presses
/// walk the app's windows, a match already here or no match at all
/// refuses without launching, and a hidden app is owed its move.
@MainActor
@Suite("move_here's command flows (#1513)", .serialized)
struct MoveHereCommandTests {
    private static let bundle = "app.test.100"

    private final class Recorder {
        var opened: [String] = []
        var activated: [pid_t] = []
        var logs: [String] = []
    }

    private func makeCore(running: Bool = true) -> (KiwiCore, Recorder) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        let recorder = Recorder()
        core.openOrFocus.runningAppPID = { _ in running ? 100 : nil }
        core.openOrFocus.activate = { recorder.activated.append($0) }
        core.openOrFocus.openApp = { id, _ in
            recorder.opened.append(id)
            return true
        }
        core.frontmostPIDProvider = { 300 }
        core.onLog = { recorder.logs.append($0) }
        core.eventLoop.shadows.focusedWindow = { _ in nil }
        for space: SpaceID in ["1", "2", "3"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        return (core, recorder)
    }

    private func addWindow(
        _ core: KiwiCore,
        _ id: UInt32,
        space: SpaceID,
        title: String = ""
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "Notes",
            appBundleID: Self.bundle
        )
        window.title = title
        core.state.windows.upsert(window)
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func run(
        _ core: KiwiCore,
        _ text: String? = nil
    ) -> CommandResponse {
        core.execute(
            "move_here",
            args: [.string(Self.bundle)] + (text.map { [.string($0)] } ?? [])
        )
    }

    private func space(_ core: KiwiCore, _ id: UInt32) -> SpaceID? {
        core.state.workspaces.space(of: WindowID(id))
    }

    @Test("repeat presses bring the app's windows one by one")
    func repeatsWalk() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "2")
        addWindow(core, 2, space: "3")
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(2))
        #expect(run(core).isSuccess)
        #expect(space(core, 2) == "1")
        #expect(space(core, 1) == "2")
        #expect(run(core).isSuccess)
        #expect(space(core, 1) == "1")
    }

    @Test("every window already here refuses, moving nothing")
    func allHereRefuses() {
        let (core, recorder) = makeCore()
        addWindow(core, 1, space: "1")
        #expect(!run(core).isSuccess)
        #expect(recorder.opened.isEmpty)
        #expect(space(core, 1) == "1")
        #expect(refused(recorder, .allHere(app: "")))
    }

    /// Whether the run logged `refusal`'s reason, the pill's own.
    private func refused(
        _ recorder: Recorder,
        _ refusal: WindowActionRefusal
    ) -> Bool {
        recorder.logs.contains { $0.contains(refusal.logReason) }
    }

    @Test("text no title holds refuses and never launches")
    func noMatchRefuses() {
        let (core, recorder) = makeCore()
        addWindow(core, 1, space: "2", title: "Drafts")
        #expect(!run(core, "inbox").isSuccess)
        #expect(space(core, 1) == "2")
        #expect(recorder.opened.isEmpty)
        #expect(refused(recorder, .noTitleMatch(app: "", text: "")))
        let (bare, bareRecorder) = makeCore(running: false)
        #expect(!run(bare, "inbox").isSuccess)
        #expect(bareRecorder.opened.isEmpty)
        #expect(refused(bareRecorder, .noTitleMatch(app: "", text: "")))
    }

    @Test("text picks the matching window, not the most recent")
    func textPicks() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "2", title: "Inbox")
        addWindow(core, 2, space: "3", title: "Drafts")
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(2))
        #expect(run(core, "inbox").isSuccess)
        #expect(space(core, 1) == "1")
        #expect(space(core, 2) == "3")
    }

    @Test("a hidden app owes its returning window the text")
    func hiddenOwesTheText() {
        let (core, recorder) = makeCore()
        core.eventLoop.appIsHidden = { _ in true }
        #expect(run(core, "inbox").isSuccess)
        #expect(recorder.activated == [100])
        #expect(core.jump.owedApp?.matching == "inbox")
        #expect(core.jump.owedApp?.space == "1")
    }
}
