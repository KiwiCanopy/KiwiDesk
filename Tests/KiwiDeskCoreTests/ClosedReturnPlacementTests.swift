import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The placement half of a close return (#1561): a window you
/// bring back is a NEW window — its app rule, else the Space you
/// are on — never the Space it left, its slot and break given up,
/// a restore filed over the close discarded. The focus half is
/// `ClosedReturnFocusTests`', split here at the §2.1 ceiling with
/// the same small fixture (§2.4).
@Suite("A close return is placed as a new window (#1561)", .serialized)
@MainActor
struct ClosedReturnPlacementTests {
    /// Two windows on one scrolling space, `other` focused —
    /// `ClosedReturnFocusTests`' fixture.
    private func makeFixture() -> (
        core: KiwiCore, target: WindowID, other: WindowID
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-closed-placement-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)",
                        frame: CGRect(
                            x: 500 * CGFloat(id - 1),
                            y: 0,
                            width: 400,
                            height: 300
                        )
                    )
                )
            )
        }
        let target = WindowID(1)
        let other = WindowID(2)
        let space = core.state.workspaces.space(of: target)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.tiler.placements = PlacementLedger()
        core.state.workspaces.focus(other, in: space)
        return (core, target, other)
    }

    /// A focused resident of `space`, so a grant there is the
    /// new-window arm's and not the vacancy arm's.
    private func seat(_ id: WindowID, in space: SpaceID, on core: KiwiCore) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: pid_t(id.raw),
                    appName: "Resident",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
        if core.state.workspaces.space(of: id) != space {
            core.state.workspaces.focus(id, in: SpaceID("1"))
            _ = core.execute(
                "move_to_space",
                args: [.string(space.raw)]
            )
        }
        core.state.workspaces.focus(id, in: space)
        #expect(core.state.workspaces.space(of: id) == space)
        #expect(core.state.workspaces[space]?.focused == id)
    }

    /// The placement half (#1561): a close return is a NEW window
    /// — the Space you are on, never the one it left — with the
    /// focus a new window gets there.
    @Test("A closed window re-shown lands where you are, focused")
    func closedReturnLandsWhereYouAre() {
        let (core, target, other) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.closedDepartures.contains(target))
        let elsewhere = SpaceID("2")
        core.state.workspaces.ensureSpace(elsewhere)
        core.state.workspaces.activate(elsewhere)
        #expect(core.state.workspaces.activeSpace == elsewhere)
        // A focused resident, so the focus clause proves the
        // new-window grant and not the vacancy arm (guard-prover).
        seat(WindowID(5), in: elsewhere, on: core)
        core.handle(.windowCreated(reshown(target)))
        #expect(core.state.workspaces.space(of: target) == elsewhere)
        #expect(core.state.workspaces[elsewhere]?.focused == target)
        #expect(core.state.workspaces[SpaceID("1")]?.focused == other)
        // Consumed, and the departed memory with it.
        #expect(!core.state.closedDepartures.contains(target))
        #expect(core.state.rememberedSpaces[target] == nil)
    }

    /// An app rule outranks "where you are" for a close return as
    /// it does for a new window (#1561).
    @Test("A closed window re-shown follows its app rule like a new one")
    func closedReturnFollowsTheAppRule() {
        let (core, target, _) = makeFixture()
        let ruled = SpaceID("2")
        core.state.workspaces.ensureSpace(ruled)
        core.state.appRules["app.one"] = ruled
        seat(WindowID(5), in: ruled, on: core)
        core.handle(.windowDestroyed(target, wasMinimized: false))
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: target,
                    pid: 1,
                    appName: "App1",
                    appBundleID: "app.one",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
        #expect(core.state.workspaces.space(of: target) == ruled)
        #expect(core.state.workspaces[ruled]?.focused == target)
    }

    /// A session restore filed OVER the mark — the window captured,
    /// closed, then a snapshot adopted before it re-shows — does not
    /// outrank the close: the re-show still lands as new, and the
    /// restore's frame is spent with the memory (#1561).
    @Test("A restore filed after the close does not outrank it")
    func restoreFiledAfterTheCloseDoesNotOutrank() {
        let (core, target, _) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.closedDepartures.contains(target))
        let elsewhere = SpaceID("2")
        core.state.workspaces.ensureSpace(elsewhere)
        core.state.remember(target, in: elsewhere)
        core.state.restoredFrames[target] = CGRect(
            x: 9,
            y: 9,
            width: 90,
            height: 90
        )
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowCreated(reshown(target)))
        #expect(core.state.workspaces.space(of: target) == SpaceID("1"))
        #expect(core.activeSpace?.focused == target)
        // The frame is spent with the memory: its consumer never
        // seeds it (the store empties on every arrival, so the
        // consumer's log is the observable).
        #expect(!log.contains { $0.contains("snapshot frame is seeded") })
        // The positive control: a `vanished` return with a
        // restored frame DOES seed it — the negative above is
        // not fail-open.
        let control = makeFixture().core
        control.lastDesktopSwitch = Date()
        control.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        control.lastDesktopSwitch = .distantPast
        control.state.restoredFrames[WindowID(1)] = CGRect(
            x: 9,
            y: 9,
            width: 90,
            height: 90
        )
        var controlLog: [String] = []
        control.onLog = { controlLog.append($0) }
        control.handle(.windowCreated(reshown(WindowID(1))))
        #expect(
            controlLog.contains { $0.contains("snapshot frame is seeded") }
        )
    }

    /// The slot and break a departed window would take back
    /// (#1207/#1387) are given up: it joins the row as a newcomer.
    @Test("A closed window re-shown gives up its old slot")
    func closedReturnGivesUpItsSlot() {
        let (core, target, other) = makeFixture()
        let third = WindowID(3)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: third,
                    pid: 3,
                    appName: "App3",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
        core.state.workspaces.focus(other, in: SpaceID("1"))
        let before = core.state.workspaces[SpaceID("1")]?.windows
        #expect(before?.first == target)
        core.handle(.windowDestroyed(target, wasMinimized: false))
        core.handle(.windowCreated(reshown(target)))
        let after = core.state.workspaces[SpaceID("1")]?.windows ?? []
        #expect(after.contains(target))
        #expect(after.first != target)
        #expect(core.state.departedSlots[target] == nil)
    }

    private func reshown(_ id: WindowID) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: pid_t(id.raw),
            appName: "App\(id.raw)",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }
}
