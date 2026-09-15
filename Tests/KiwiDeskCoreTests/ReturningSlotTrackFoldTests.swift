import Foundation
import Testing

@testable import KiwiDeskCore

// The track half of a Desktop return (#1387): a return takes
// its rank ahead of the spawn rule, and the break it had — the
// record carries the break's provenance, since `Space.remove`
// hands a departing head's break to its successor.

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

@Suite("A Desktop return keeps a track row's columns (#1387)")
struct ReturningSlotTrackFoldTests {
    /// The provenance, not the live set: after `a` leaves, its
    /// break sits on `b`, and `b`'s own departure must not record
    /// that as a head of its own.
    @Test("the departure records each break's provenance")
    func departureRecordsProvenance() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a, c] }
        depart(&state, [a])
        #expect(state.workspaces[home]?.trackBreaks == [b, c])
        depart(&state, [b, c, d])
        #expect(
            state.departedSlots == [
                a: Slot(rank: 0, trackBreak: .head, handedTo: b),
                b: Slot(rank: 1, trackBreak: .handed),
                c: Slot(rank: 2, trackBreak: .head, handedTo: d),
                d: Slot(rank: 3, trackBreak: .handed),
            ]
        )
    }

    /// The device row (2026-09-15): four own-track columns, back in
    /// re-track order and one column fewer. The rank return must
    /// outrank the spawn rule.
    @Test("a scrambled re-track rebuilds the columns it left")
    func scrambledReturnRebuildsTheColumns() {
        var state = makeTrackRow()
        depart(&state, [a, b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [])
        for id in [d, b, c, a] {
            state.apply(.windowCreated(makeWindow(id)))
        }
        #expect(state.workspaces[home]?.windows == [a, b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a, b, c, d])
    }

    /// A partition with members: the heads take their breaks back
    /// and the members return without one, in any order.
    @Test("a mixed partition comes back as it left")
    func mixedPartitionComesBack() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a, c] }
        depart(&state, [a, b, c, d])
        for id in [c, a, d, b] {
            state.apply(.windowCreated(makeWindow(id)))
        }
        #expect(state.workspaces[home]?.windows == [a, b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
    }

    /// `Space.remove` hands a departing head's break AND weight to
    /// its successor; the return is that hand-off's inverse, so a
    /// stayer that was given them gives them back, and its record
    /// no longer says handed.
    @Test("a stayer hands the break and weight back")
    func stayerHandsTheBreakBack() {
        var state = StateCoordinator(defaultSpace: home)
        state.workspaces.setMode(home, .track)
        state.trackParams.newWindow = .focusedTrack
        state.trackParams.newWindowPosition = .afterFocused
        let stayer = WindowID(9)
        for id in [a, stayer] {
            state.apply(.windowCreated(makeWindow(id)))
            state.apply(.windowFocused(id))
        }
        state.workspaces.withSpace(home) {
            $0.trackBreaks = [a]
            $0.trackWeights = [a: 1.5]
        }
        depart(&state, [a])
        #expect(state.workspaces[home]?.trackBreaks == [stayer])
        #expect(state.workspaces[home]?.handedBreaks == [stayer])
        #expect(state.workspaces[home]?.trackWeights == [stayer: 1.5])
        #expect(state.departedSlots[a]?.handedTo == stayer)
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.windows == [a, stayer])
        #expect(state.workspaces[home]?.trackBreaks == [a])
        #expect(state.workspaces[home]?.handedBreaks == [])
        #expect(state.workspaces[home]?.trackWeights == [a: 1.5])
        // The link is spent.
        #expect(state.departedSlots[a]?.handedTo == nil)
    }

    /// The ruling (owner, 2026-09-15): a handed break is never
    /// handed on. `b` departs holding `a`'s and drops it; `c` is
    /// never marked; `a`'s return re-inserts its own, whichever
    /// of the two is back first.
    @Test("a handed break is dropped at its holder's departure")
    func handedBreakIsDroppedNotHandedOn() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a, b])
        #expect(state.workspaces[home]?.trackBreaks == [])
        #expect(state.departedSlots[b]?.handedTo == nil)
        #expect(state.departedSlots[c]?.trackBreak == .member)
        state.apply(.windowCreated(makeWindow(b)))
        #expect(state.workspaces[home]?.trackBreaks == [])
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.windows == [a, b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a])
    }

    @Test("the head returning first takes the break back too")
    func headFirstTakesItBack() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a, b])
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.trackBreaks == [a])
        state.apply(.windowCreated(makeWindow(b)))
        #expect(state.workspaces[home]?.windows == [a, b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a])
    }

    /// A departing member whose successor already heads a track
    /// hands nothing on, and that head's own break is never
    /// stripped by an earlier head's return.
    @Test("a head of its own is never stripped")
    func ownHeadIsNeverStripped() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a, c] }
        depart(&state, [a, b])
        #expect(state.workspaces[home]?.trackBreaks == [c])
        #expect(state.departedSlots[c]?.trackBreak == .head)
        #expect(state.departedSlots[a]?.handedTo == b)
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
    }

    /// A member that departed before its head and returned before
    /// it sits between the head and the holder; the record names
    /// the holder, so the member's row position is nothing.
    @Test("a member back ahead of its head does not hide the holder")
    func memberBetweenHeadAndHolderIsWalkedPast() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [b, a])
        #expect(state.workspaces[home]?.trackBreaks == [c])
        state.apply(.windowCreated(makeWindow(b)))
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.windows == [a, b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a])
    }

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

    @Test("a re-key carries the provenance with the slot")
    func rekeyCarriesTheProvenance() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a, c] }
        depart(&state, [a, b, c, d])
        state.apply(.windowRekeyed(c, WindowID(9)))
        #expect(
            state.departedSlots[WindowID(9)]
                == Slot(rank: 2, trackBreak: .head, handedTo: d)
        )
        // A link naming the old id follows it too.
        state.apply(.windowRekeyed(b, WindowID(8)))
        #expect(state.departedSlots[a]?.handedTo == WindowID(8))
    }
}
