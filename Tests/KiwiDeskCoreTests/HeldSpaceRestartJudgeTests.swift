import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Which restored held windows boot keeps (#1646): the per-window
/// WindowServer read after the away seed drops only a window
/// hosted nowhere, and a hold going home takes every window it
/// remembers with it. `HeldSpaceRestartTests`' desk and boot.
@Suite("Held Space restart judge (#1646)", .serialized)
@MainActor
struct HeldSpaceRestartJudgeTests {
    private let t = HeldSpaceRestartTests()
    private var desk: HeldSpaceDesk { t.desk }

    /// Process B undocked on `solo`, scanning `windows`.
    private func bootSolo(
        _ a: KiwiCore,
        windows: [Int]
    ) throws -> KiwiCore {
        t.boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            windows: windows,
            session: try t.crossed(a.sessionSnapshot())
        )
    }

    @Test("a hidden app's window keeps its held Space across the restart")
    func hiddenMemberKeepsTheHold() throws {
        let a = try t.unplugged()
        a.handle(.windowHidden(WindowID(12)))
        #expect(a.state.heldSpaces[SpaceID(6)] != nil)
        let b = try bootSolo(a, windows: [13, 10, 11])
        b.desktopMemory.readWindowSpace = t.hosting([12])
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(6)]?.name == SpaceID(4))
        #expect(
            b.state.rememberedSpaces[WindowID(12)] == .restored(SpaceID(6))
        )
        b.handle(.windowCreated(desk.window(12)))
        #expect(b.state.workspaces.space(of: WindowID(12)) == SpaceID(6))
    }

    @Test("a window on another Desktop keeps its held Space too")
    func awayMemberKeepsTheHold() throws {
        let a = try t.unplugged()
        let away = WindowID(12)
        a.state.workspaces.remove(away)
        a.state.windows.remove(away)
        a.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: 1,
            appName: "App12",
            appBundleID: nil,
            nativeSpace: 4
        )
        a.state.rememberedSpaces[away] = .departed(SpaceID(6))
        a.retile()
        #expect(a.state.heldSpaces[SpaceID(6)] != nil)
        let b = try bootSolo(a, windows: [13, 10, 11])
        b.desktopMemory.readWindowSpace = t.hosting([12])
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(6)] != nil)
        #expect(b.state.rememberedSpace(of: away) == SpaceID(6))
    }

    /// A deferred app's windows: hosted, not yet adopted — the
    /// judge runs before `drainDeferredBootApps`.
    @Test("a window still launching at boot keeps its held Space")
    func lateMemberKeepsTheHold() throws {
        let a = try t.unplugged()
        let b = try bootSolo(a, windows: [13, 12])
        b.desktopMemory.readWindowSpace = t.hosting([13, 10, 11, 12])
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)]?.name == SpaceID(3))
        b.handle(.windowCreated(desk.window(10)))
        #expect(b.state.workspaces.space(of: WindowID(10)) == SpaceID(5))
    }

    /// The Desktop census lists user Desktops only, so a window on
    /// a native-fullscreen Space is absent from it; the per-window
    /// read sees its Space.
    @Test("a window on a fullscreen Space keeps its held Space")
    func fullscreenMemberKeepsTheHold() throws {
        let a = try t.unplugged()
        let b = try bootSolo(a, windows: [13, 12])
        b.desktopMemory.readCensus = { _ in
            DesktopCensus(hosts: [:], shown: [])
        }
        b.desktopMemory.readWindowSpace = t.hosting([10, 11], on: 99)
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)]?.name == SpaceID(3))
    }

    @Test("a hold whose windows are gone ends once the read says so")
    func goneWindowsRetireAfterBoot() throws {
        let a = try t.unplugged()
        let b = try bootSolo(a, windows: [13, 12])
        // Kept through the replay: nothing has judged 10 and 11.
        #expect(b.state.heldSpaces[SpaceID(5)] != nil)
        b.desktopMemory.readWindowSpace = { _ in .unavailable }
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)] != nil)
        b.desktopMemory.readWindowSpace = t.hosting([13, 12])
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)] == nil)
        #expect(b.state.workspaces[SpaceID(5)] == nil)
        #expect(b.state.heldSpaces[SpaceID(6)]?.name == SpaceID(4))
    }

    /// Without the read, a closed window's filing would be written
    /// back at every quit and keep the hold for good.
    @Test("an unjudged restored filing crosses one restart, not two")
    func unjudgedFilingIsNotCarriedAgain() throws {
        let a = try t.unplugged()
        let b = try bootSolo(a, windows: [13, 12])
        b.desktopMemory.readWindowSpace = { _ in .unavailable }
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)] != nil)
        let record = b.sessionSnapshot().spaces.first { $0.id == "5" }
        #expect(record?.held != nil)
        #expect(record?.held?.remembered == [])
        let c = t.boot(
            from: b,
            screens: [desk.builtIn],
            profile: "solo",
            windows: [13, 12],
            session: try t.crossed(b.sessionSnapshot())
        )
        #expect(c.state.heldSpaces[SpaceID(5)] == nil)
        #expect(c.state.heldSpaces[SpaceID(6)] != nil)
    }

    /// A hold going home NOT in place (5 back into 3): the hidden
    /// window it remembers is re-pointed at 3, so its arrival
    /// cannot re-create 5 as an ordinary Space a save captures.
    @Test("a hold going home takes its hidden window along at boot")
    func homeReturnRepointsTheHiddenWindow() throws {
        let a = try t.unplugged()
        a.handle(.windowHidden(WindowID(10)))
        let b = t.boot(
            from: a,
            screens: [desk.builtIn, desk.dell],
            profile: "desk",
            windows: [13, 11, 12],
            session: try t.crossed(a.sessionSnapshot())
        )
        #expect(b.state.heldSpaces.isEmpty)
        #expect(b.state.rememberedSpace(of: WindowID(10)) == SpaceID(3))
        b.handle(.windowCreated(desk.window(10)))
        #expect(b.state.workspaces.space(of: WindowID(10)) == SpaceID(3))
        #expect(b.state.workspaces[SpaceID(5)] == nil)
        #expect(!b.capturedSpaces.map(\.id).contains(SpaceID(5)))
    }
}
