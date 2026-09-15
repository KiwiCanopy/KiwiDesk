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
                a: Slot(rank: 0, trackBreak: .head),
                b: Slot(rank: 1, trackBreak: .handed),
                c: Slot(rank: 2, trackBreak: .head),
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
        #expect(state.workspaces[home]?.trackWeights == [stayer: 1.5])
        #expect(state.departedSlots[stayer]?.trackBreak == .handed)
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.windows == [a, stayer])
        #expect(state.workspaces[home]?.trackBreaks == [a])
        #expect(state.workspaces[home]?.trackWeights == [a: 1.5])
        #expect(state.departedSlots[stayer]?.trackBreak == .member)
    }

    /// A chain of departures hands one break along: `a`'s sits on
    /// `c` after `b` leaves too. `b` comes back without one, and
    /// `a`'s return walks past `b` to take it back from `c`.
    @Test("a break handed along a chain is taken back from its holder")
    func handedChainIsUnwound() {
        var state = makeTrackRow()
        state.workspaces.withSpace(home) { $0.trackBreaks = [a] }
        depart(&state, [a, b])
        #expect(state.workspaces[home]?.trackBreaks == [c])
        state.apply(.windowCreated(makeWindow(b)))
        #expect(state.workspaces[home]?.windows == [b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [c])
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.windows == [a, b, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a])
        #expect(state.departedSlots[c]?.trackBreak == .member)
    }

    /// The other order: the head returns before the member that
    /// handed its break on, and takes it back from the same holder.
    @Test("the head returning first takes the break back too")
    func headFirstUnwindsTheChain() {
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
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
    }

    /// A member that departed before its head and returned before
    /// it sits between the head and the holder: the walk passes
    /// any member holding no break, whatever its record.
    @Test("a member back ahead of its head does not stop the walk")
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
        #expect(state.departedSlots[c]?.trackBreak == .handed)
        state.forgetAway(b)
        #expect(state.departedSlots[c]?.trackBreak == .head)
        depart(&state, [c])
        state.apply(.windowCreated(makeWindow(c)))
        #expect(state.workspaces[home]?.windows == [a, c, d])
        #expect(state.workspaces[home]?.trackBreaks == [a, c])
    }

    @Test("a re-key carries the provenance with the slot")
    func rekeyCarriesTheProvenance() {
        var state = makeTrackRow()
        depart(&state, [a, b, c, d])
        state.apply(.windowRekeyed(c, WindowID(9)))
        #expect(
            state.departedSlots[WindowID(9)]
                == Slot(rank: 2, trackBreak: .head)
        )
    }
}
