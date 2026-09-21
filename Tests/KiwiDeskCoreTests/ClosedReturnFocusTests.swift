import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A window returning from a CLOSE takes the focus at its
/// arrival (#1414), and is placed as a NEW window — its app rule,
/// else the Space you are on (#1561): the gone handler marks the
/// departure, the create fold reads the mark, and the app's own
/// make-key report then reaches the placement distrust with the
/// focus already intended — measured 3 of 3 bounced in scrolling
/// on the device before this, 0 in bsp. A Desktop return keeps
/// #636's rule; a minimize carries no mark; the mark is consumed
/// on every arrival.
@Suite("A window returning from a close takes the focus (#1414)", .serialized)
@MainActor
struct ClosedReturnFocusTests {
    private final class Log {
        var lines: [String] = []
    }

    private let offscreen = CGRect(
        x: 1200,
        y: 100,
        width: 400,
        height: 300
    )

    /// `PlacementIntentTests`' fixture, kept small rather than
    /// shared (§2.4): two windows on one scrolling space, `other`
    /// focused.
    private func makeFixture() -> (
        core: KiwiCore, target: WindowID, other: WindowID
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-closed-return-\(UUID().uuidString)"
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

    private func reshown(_ id: WindowID) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: pid_t(id.raw),
            appName: "App\(id.raw)",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    @Test("A closed window re-shown takes the focus; its report is honored")
    func closedReturnTakesFocus() {
        let (core, target, other) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        // The gone handler classified a close and marked it —
        // fail-open guard for every clause below.
        #expect(core.state.closedDepartures.contains(target))
        #expect(core.activeSpace?.focused == other)
        let log = Log()
        core.onLog = { log.lines.append($0) }
        core.handle(.windowCreated(reshown(target)))
        #expect(core.activeSpace?.focused == target)
        #expect(
            log.lines.contains {
                $0.contains("close return: w1 re-shown — placed as new")
            }
        )
        // Consumed by the arrival.
        #expect(!core.state.closedDepartures.contains(target))
        // The arrival's retile stamped it; the report still
        // lands intended — asserted on the log, since with
        // `intended == id` the bounce's re-assert would put the
        // same focus back and state alone cannot tell.
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(log.lines.contains { $0.contains("w1 (App1) honored") })
        #expect(
            !log.lines.contains {
                $0.contains("placement bounce distrusted")
            }
        )
    }

    @Test("A window that left with its Desktop steals nothing at its return")
    func vanishedReturnStealsNothing() {
        let (core, target, other) = makeFixture()
        // Inside the switch settle the #40 timer reads the
        // departure as `vanished` (no compositor answer in a
        // fixture) — the Desktop-departure class.
        core.lastDesktopSwitch = Date()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(!core.state.closedDepartures.contains(target))
        core.handle(.windowCreated(reshown(target)))
        #expect(core.activeSpace?.focused == other)
    }

    /// A construction net for the CALL site: `classify` answers
    /// `.minimized` before presence is read, so the gone handler
    /// never marks a minimize. The writer's own guard is the
    /// clause below.
    @Test("A minimize carries no close mark")
    func minimizeCarriesNoMark() {
        let (core, target, _) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: true))
        #expect(!core.state.closedDepartures.contains(target))
    }

    /// The writer marks only a DEPARTED window: a `.restored`
    /// session filing that never arrived, or an id no fold ever
    /// filed, is not a return and takes no mark (guard-prover,
    /// 2026-09-21: the minimize net above cannot reach this).
    @Test("Only a departed window can carry the mark")
    func onlyADepartedWindowIsMarked() {
        var state = StateCoordinator()
        let restored = WindowID(21)
        state.remember(restored, in: SpaceID("1"))
        state.rememberClosedDeparture(restored)
        #expect(!state.closedDepartures.contains(restored))
        let unfiled = WindowID(22)
        state.rememberClosedDeparture(unfiled)
        #expect(!state.closedDepartures.contains(unfiled))
        // The positive control: a departed window is marked.
        state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(23), pid: 1, appName: "App")
            )
        )
        state.apply(.windowDestroyed(WindowID(23), wasMinimized: false))
        state.rememberClosedDeparture(WindowID(23))
        #expect(state.closedDepartures.contains(WindowID(23)))
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
        core.handle(.windowCreated(reshown(target)))
        #expect(core.state.workspaces.space(of: target) == SpaceID("1"))
        #expect(core.activeSpace?.focused == target)
        #expect(core.state.restoredFrames[target] == nil)
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

    /// A Desktop return's vacancy hold (#1207) keeps other
    /// RETURNING windows off the focus while the owed window is
    /// still departed; a close return is a NEW window and takes
    /// the focus like one — the honored report that follows
    /// retires the debt the way any honored focus does.
    @Test("A close return outranks a Desktop return's vacancy hold")
    func closeReturnOutranksTheVacancyHold() {
        let (core, target, _) = makeFixture()
        // Window 3 leaves with its Desktop (the #40 timer reads
        // the departure inside the settle) and is owed the focus
        // at its return.
        let owed = WindowID(3)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: owed,
                    pid: 3,
                    appName: "App3",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
        core.state.workspaces.focus(target, in: SpaceID("1"))
        core.lastDesktopSwitch = Date()
        core.handle(.windowDestroyed(owed, wasMinimized: false))
        core.lastDesktopSwitch = .distantPast
        // Stamped AHEAD: the debt drains on a wall clock, and a
        // starved runner must not let the hold vanish between
        // the record and the arrival (#1371, tests.md).
        core.desktopMemory.returnFocus.record(
            owed,
            at: Date(timeIntervalSinceNow: 60)
        )
        #expect(core.desktopMemory.returnFocus.owed() == owed)
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.closedDepartures.contains(target))
        core.handle(.windowCreated(reshown(target)))
        #expect(core.activeSpace?.focused == target)
    }

    @Test("The mark rides a re-key with the departed memory")
    func markFollowsRekey() {
        let (core, target, _) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.closedDepartures.contains(target))
        let new = WindowID(9)
        core.state.rekey(target, to: new)
        #expect(!core.state.closedDepartures.contains(target))
        #expect(core.state.closedDepartures.contains(new))
    }
}
