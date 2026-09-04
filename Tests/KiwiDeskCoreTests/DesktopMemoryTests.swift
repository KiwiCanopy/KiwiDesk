import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-Desktop Space memory, keyed by the DESKTOP (#1147):
/// which Space a Desktop returns to, the two staleness edges
/// #888 named, and the partition #1147 retired.
///
/// Serialized, synchronous bodies: see `DesktopAuthorityTests`;
/// the fixture is `DesktopAuthorityFixture.swift`.
@Suite("Per-Desktop Space memory (#888)", .serialized)
@MainActor
struct DesktopMemoryTests {
    private let stamp = DesktopIdentity(raw: "STAMP-A")

    @Test("A remembered Space foreign to the space set falls back")
    func staleFallsBack() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.desktopMemory.virtualSpaces[.number(3)] = SpaceID(9)
        let snapshot = authoritySnapshot()
        // Space "9" is no profile's — the binding apply that
        // precedes this read may have swapped the space set — so
        // stale takes the same exit as missing. Asserted as that
        // EQUIVALENCE rather than against a value: #1230 changed
        // what the exit answers, and the rule it must keep is
        // that both take it (tests.md ▸ pin the shape).
        #expect(
            core.virtualSpaceTarget(for: .number(3), in: snapshot)
                == core.virtualSpaceTarget(
                    for: .number(99),
                    in: snapshot
                )
        )
    }

    /// Two Desktops are two entries, whichever shape their keys
    /// have: the memory answers for the Desktop asked about and
    /// never for its neighbour.
    @Test("Memory belonging to another Desktop is not read")
    func perDesktopKeying() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.desktopMemory.virtualSpaces[.number(4)] = SpaceID(2)
        core.desktopMemory.virtualSpaces[.identity(stamp)] =
            SpaceID(2)
        let snapshot = authoritySnapshot()
        // Never the neighbour's Space — and since #1230 a Space
        // another Desktop is showing is exactly what the fallback
        // now steps over, so this reads as "not 2" rather than as
        // a pinned answer.
        #expect(
            core.virtualSpaceTarget(for: .number(3), in: snapshot)
                != SpaceID(2)
        )
    }

    /// A stamped Desktop and its Mission Control number are two
    /// keys, and that is the point: the number is what a
    /// renumber moves, so an entry filed under the stamp must
    /// not be reachable by the number that happens to name it.
    @Test("An identity and a number are different keys")
    func identityIsNotItsNumber() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        // Three Spaces, and the stamp remembers the LAST one: with
        // two, the #1230 fallback also answers "2" and the
        // assertion could not tell a read of the stamp's entry
        // from a fallback that happened to agree.
        core.state.workspaces.ensureSpace(SpaceID(3))
        core.rememberVirtualSpace(SpaceID(3), leaving: .identity(stamp))
        let snapshot = authoritySnapshot()
        #expect(
            core.virtualSpaceTarget(
                for: .identity(stamp),
                in: snapshot
            ) == SpaceID(3)
        )
        // The number reaches no entry, so it takes the fallback
        // rather than the stamp's memory.
        #expect(
            core.virtualSpaceTarget(for: .number(3), in: snapshot)
                != SpaceID(3)
        )
    }

    /// The keying was (main display UUID, Mission Control
    /// number) until a Desktop could name itself (#1147, R2b).
    /// The partition existed because a number means nothing
    /// without saying whose numbering it is — a stamp means the
    /// same thing on every arrangement, so re-partitioning it
    /// would make a Desktop forget its Space whenever the user
    /// changed which screen carries the menu bar.
    ///
    /// It follows that the keying still cannot depend on the
    /// separate-Spaces mode, which flips at the next login and
    /// gets no migration — the stronger form of #888's own
    /// promise, since nothing on this path reads that preference
    /// at all.
    @Test("A stamped Desktop keeps its Space when the main screen changes")
    func identityOutlivesTheMainDisplay() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.rememberVirtualSpace(SpaceID(2), leaving: .identity(stamp))
        let snapshot = authoritySnapshot()
        NativeSpaces.mainDisplayUUIDOverride = "UUID-B"
        #expect(
            core.virtualSpaceTarget(
                for: .identity(stamp),
                in: snapshot
            ) == SpaceID(2)
        )
    }

    /// Boot seeds the per-display reading (review, 2026-08-18).
    /// Left empty, the session's first switch diffs against
    /// nothing, reads every display as changed, and attributes a
    /// secondary swipe to `monitor: 1`.
    @Test("A seeded snapshot reports no switch of its own")
    func seedingLeavesNoDiff() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        let core = makeAuthorityCore()
        let snapshot = NativeSpaces.desktopSnapshot()
        core.desktopMemory.seed(snapshot)
        #expect(core.switchedDisplays(in: snapshot).isEmpty)
    }
}
