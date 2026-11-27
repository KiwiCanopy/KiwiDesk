import AppKit
import Testing

@testable import KiwiDeskCore

/// KiwiHub's Applications section, Core's half (#3704): the
/// snapshot names the running apps and which hold a row, the press
/// asks `openAppRefusal`, and `openApp` launches or reopens through
/// the one launcher, owing the launch follow. Main-actor spend: one
/// test core per test, no scan.
@Suite("KiwiHub opens apps that are not open (#3704)", .serialized)
@MainActor
struct JumpOpenAppTests {
    static let notes = "app.test.notes"
    static let mail = "app.test.mail"

    final class Recorder {
        var opened: [(String, OpenAppMode)] = []
    }

    private func makeCore(
        found: Bool = true
    ) -> (KiwiCore, Recorder) {
        let core = makeTestCore()
        let recorder = Recorder()
        core.openOrFocus.openApp = { id, mode in
            recorder.opened.append((id, mode))
            return found
        }
        core.openOrFocus.resolves = { _ in found }
        core.eventLoop.activationPolicy = { _ in .regular }
        core.eventLoop.runningApplications = {
            [
                RunningApp(
                    pid: 900_001,
                    activationPolicy: .regular,
                    ref: AppRef(bundleID: Self.notes, name: "Notes")
                ),
                RunningApp(
                    pid: 900_002,
                    activationPolicy: .regular,
                    ref: AppRef(bundleID: "App.Test.Mail", name: "Mail")
                ),
            ]
        }
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.activate("1")
        return (core, recorder)
    }

    private func track(_ core: KiwiCore, pid: pid_t) {
        var window = ManagedWindow(
            id: WindowID(1),
            pid: pid,
            appName: "Notes",
            appBundleID: Self.notes
        )
        window.title = "Ideas"
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(1), to: SpaceID("1"))
    }

    @Test("the snapshot names running apps, listed where a row is theirs")
    func runningApps() {
        let (core, _) = makeCore()
        track(core, pid: 900_001)
        let running = core.jumpSnapshot().running
        #expect(
            running
                == [
                    JumpRunningApp(
                        bundleID: Self.notes,
                        name: "Notes",
                        listed: true
                    ),
                    JumpRunningApp(
                        bundleID: Self.mail,
                        name: "Mail",
                        listed: false
                    ),
                ]
        )
    }

    @Test("↩ reopens through the launcher and owes the follow")
    func opens() {
        let (core, recorder) = makeCore()
        #expect(core.openAppRefusal(Self.mail) == nil)
        #expect(core.openApp("App.Test.Mail"))
        #expect(recorder.opened.map(\.0) == [Self.mail])
        #expect(recorder.opened.map(\.1) == [.reopen])
        #expect(core.launchFollow.owed() == Self.mail)
    }

    @Test("an app LaunchServices cannot find refuses, owing nothing")
    func notFound() {
        let (core, _) = makeCore(found: false)
        #expect(core.openAppRefusal(Self.mail) == .notFound)
        #expect(!core.openApp(Self.mail))
        #expect(core.launchFollow.owed() == nil)
    }

    @Test("one matcher: a name's start ranks before its inside")
    func nameMatch() throws {
        let start = try #require(JumpSearch.nameMatch("sa", in: "Safari"))
        #expect(start.tier == 0)
        let inside = try #require(JumpSearch.nameMatch("fa", in: "Safari"))
        #expect(inside.tier == 1)
        #expect(String("Safari"[inside.range]) == "fa")
        #expect(JumpSearch.nameMatch(" ", in: "Safari") == nil)
        #expect(JumpSearch.nameMatch("x", in: "Safari") == nil)
    }
}
