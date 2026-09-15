import Foundation
import Testing

@testable import KiwiDeskCore

// The hand-off's enders (#1387): a head gone for good promotes
// the holder its record names, and a head removed by anything
// but a Desktop departure hands for good. The return half is
// `ReturningSlotTrackFoldTests`.

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
private let home = SpaceID("1")

private typealias Slot = StateCoordinator.DepartedSlot

private func makeWindow(_ id: WindowID) -> ManagedWindow {
    ManagedWindow(id: id, pid: pid_t(id.raw), appName: "App\(id.raw)")
}

/// A track row under the owner's settings — every window its own
/// column, new ones at the front — built in reverse so the row
/// reads [a, b, c, d].
private func makeTrackRow() -> StateCoordinator {
    var state = StateCoordinator(defaultSpace: home)
    state.workspaces.setMode(home, .track)
    state.trackParams.newWindow = .ownTrack
    state.trackParams.newWindowPosition = .first
    for id in [d, c, b, a] {
        state.apply(.windowCreated(makeWindow(id)))
    }
    #expect(state.workspaces[home]?.windows == [a, b, c, d])
    #expect(state.workspaces[home]?.trackBreaks == [a, b, c, d])
    return state
}

private func depart(_ state: inout StateCoordinator, _ ids: [WindowID]) {
    for id in ids {
        state.apply(.windowDestroyed(id, wasMinimized: false))
    }
}

@Suite("A head gone for good promotes its holder (#1387)")
struct HandedBreakEnderTests {
    /// A head closed while away makes its hand-off permanent: the
    /// holder becomes a head of its own, so its own round trip
    /// brings the break back with it rather than leaving it on
    /// the member behind.
    @Test("a head gone for good promotes its holder")
    func retiredHeadPromotesItsHolder() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a, b] }
        depart(&state, [b])
        #expect(state.workspaces[home]?.handedBreaks == [c])
        state.forgetAway(b)
        #expect(state.workspaces[home]?.handedBreaks == [])
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
        depart(&state, [c])
        #expect(state.departedSlots[c]?.trackBreak == .head)
        state.apply(.windowCreated(makeWindow(c)))
        #expect(state.workspaces[home]?.windows == [a, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
    }

    /// The promotion goes to the holder the record NAMES, never to
    /// the nearest handed record: a head whose successor already
    /// held a break handed nothing, and its close promotes nobody
    /// (review, 2026-09-15).
    @Test("a closed head that handed nothing promotes nobody")
    func headThatHandedNothingPromotesNobody() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a, b] }
        depart(&state, [b, a, c, d])
        #expect(state.departedSlots[a]?.handedTo == nil)
        #expect(state.departedSlots[c]?.trackBreak == .handed)
        state.forgetAway(a)
        #expect(state.departedSlots[c]?.trackBreak == .handed)
        for id in [b, c, d] {
            state.apply(.windowCreated(makeWindow(id)))
        }
        #expect(state.workspaces[home]?.trackBreaks == [b])
    }

    /// A holder that dropped the break at its own departure is
    /// still the one promoted: it heads the track by right now, and
    /// re-inserts a break of its own on return.
    @Test("a closed head promotes a holder that is away too")
    func closedHeadPromotesAnAwayHolder() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a, b, c])
        state.forgetAway(a)
        #expect(state.departedSlots[b]?.trackBreak == .head)
        #expect(state.departedSlots[c]?.trackBreak == .member)
        state.apply(.windowCreated(makeWindow(c)))
        state.apply(.windowCreated(makeWindow(b)))
        #expect(state.workspaces[home]?.windows == [b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [b])
    }

    /// The enders of a head's record, each promoting its holder
    /// through its own door.
    enum Ender: CaseIterable {
        case redirect, refile, appExit, close
    }

    @Test(
        "every ender of a head's record promotes its holder",
        arguments: Ender.allCases
    )
    func everyEnderPromotes(ender: Ender) {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a])
        #expect(state.departedSlots[a]?.handedTo == b)
        #expect(state.workspaces[home]?.handedBreaks == [b])
        state.workspaces.ensureSpace(SpaceID("2"))
        switch ender {
        case .redirect:
            state.redirectDeparture(of: a, to: SpaceID("2"))
        case .refile:
            state.refileAway(of: a, to: SpaceID("2"))
        case .appExit:
            state.awayWindows[a] = AwayWindow(
                id: a,
                pid: pid_t(a.raw),
                appName: "App",
                appBundleID: nil,
                nativeSpace: SkyLight.SpaceID(9),
                isUp: true
            )
            state.apply(.appTerminated(pid: pid_t(a.raw)))
            #expect(state.departedSlots[a] == nil)
        case .close:
            state.forgetAway(a)
        }
        #expect(state.workspaces[home]?.handedBreaks == [])
        #expect(state.workspaces[home]?.trackBreaks == [b])
    }

    /// The same enders promote a holder that is AWAY, on its
    /// record.
    @Test("an ender promotes an away holder on its record")
    func enderPromotesAnAwayHolder() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a, b])
        #expect(state.departedSlots[b]?.trackBreak == .handed)
        state.redirectDeparture(of: a, to: home)
        #expect(state.departedSlots[b]?.trackBreak == .head)
        #expect(state.departedSlots[a] == nil)
    }

    /// The app-exit fold removes LIVE windows too, and a holder
    /// among them drops the break rather than handing it on.
    @Test("an app exit drops a live holder's handed break")
    func appExitDropsALiveHoldersBreak() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a])
        #expect(state.workspaces[home]?.trackBreaks == [b])
        state.apply(.appTerminated(pid: pid_t(b.raw)))
        #expect(state.workspaces[home]?.windows == [c, d])
        #expect(state.workspaces[home]?.trackBreaks == [])
    }

    /// A link the head's return could not spend in a non-track
    /// mode must not mark a live own head at a later minimize
    /// (review, 2026-09-15): the mark comes from the record the
    /// departure writes, and the link is spent on every return.
    @Test("a link that outlived a mode flip never marks")
    func staleLinkNeverMarks() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a])
        #expect(state.departedSlots[a]?.handedTo == b)
        state.workspaces.setMode(home, .bsp)
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.departedSlots[a]?.handedTo == nil)
        state.workspaces.setMode(home, .track)
        #expect(state.workspaces[home]?.trackBreaks == [a, b, c, d])
        state.apply(.windowDestroyed(a, wasMinimized: true))
        #expect(state.workspaces[home]?.handedBreaks == [])
        depart(&state, [b])
        state.apply(.windowCreated(makeWindow(b)))
        #expect(state.workspaces[home]?.trackBreaks == [b, c, d])
    }

    /// A head removed by anything but a Desktop departure — its
    /// app quitting, a move to another Space, a minimize — hands
    /// its break for good: no record could reclaim it, so the
    /// holder heads by right and its own round trip keeps the
    /// column (review, 2026-09-15).
    @Test(
        "an unrecorded hand-off is the holder's own",
        arguments: ["quit", "move", "minimize"]
    )
    func unrecordedHandOffIsOwn(door: String) {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a, b] }
        switch door {
        case "quit":
            state.apply(.appTerminated(pid: pid_t(b.raw)))
        case "move":
            state.workspaces.ensureSpace(SpaceID("2"))
            state.workspaces.add(b, to: SpaceID("2"))
        default:
            state.apply(.windowDestroyed(b, wasMinimized: true))
        }
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
        #expect(state.workspaces[home]?.handedBreaks == [])
        depart(&state, [c])
        state.apply(.windowCreated(makeWindow(c)))
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
    }

}
