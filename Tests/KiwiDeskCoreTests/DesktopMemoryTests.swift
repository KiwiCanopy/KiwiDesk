import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-Desktop Space memory, re-keyed per display (#888):
/// which Space a Desktop returns to, and the two staleness edges
/// the issue named.
///
/// Serialized, synchronous bodies: see `DesktopAuthorityTests`;
/// the fixture is `DesktopAuthorityFixture.swift`.
@Suite("Per-Desktop Space memory (#888)", .serialized)
@MainActor
struct DesktopMemoryTests {
    @Test("A remembered Space foreign to the space set falls back")
    func staleFallsBack() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.desktopMemory.virtualSpaces["UUID-A"] = [
            3: SpaceID(9)
        ]
        // Space "9" is no profile's — the binding apply that
        // precedes this read may have swapped the space set —
        // so stale takes the same exit as missing.
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(1)
        )
    }

    @Test("Memory keyed to another display is not read")
    func perDisplayKeying() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.desktopMemory.virtualSpaces["UUID-B"] = [
            3: SpaceID(2)
        ]
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(1)
        )
    }

    /// The mode flip applies at the next login, so the keying has
    /// to answer the same in both directions with no migration —
    /// the key is (display, Mission Control number) either way.
    ///
    /// Asserted as an invariant of the KEY rather than by pinning
    /// a mode: since the review collapsed the switch decision
    /// onto the topology snapshot, nothing in this path reads the
    /// separate-Spaces preference at all, which is the stronger
    /// form of the same promise.
    @Test("The keying does not depend on the separate-Spaces mode")
    func modeIndifferent() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.rememberVirtualSpace(SpaceID(2), leaving: 3)
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(2)
        )
        // The same entry, read back under a different main
        // display: a different key, so the answer is the default
        // rather than another arrangement's Space.
        NativeSpaces.mainDisplayUUIDOverride = "UUID-B"
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(1)
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
