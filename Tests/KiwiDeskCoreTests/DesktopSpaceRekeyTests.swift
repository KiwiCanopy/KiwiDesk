import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space memory is filed under the key the CURRENT topology
/// answers to (#1230), re-keyed on the same reading the bindings
/// re-key on.
///
/// The defect this closes: `stampedDesktopSnapshot` returns the
/// CONFIRMED reading, so a Desktop stamped this session keys by
/// its NUMBER for exactly one call — the call that files its
/// departure — and by its identity forever after. Every later
/// return missed, and `spacesShownElsewhere` read that Desktop's
/// own orphaned entry as another Desktop's, so the first-visit
/// pick actively AVOIDED the Space it had been left on. On a
/// freshly created Desktop that is #1230's own defect.
@Suite("Desktop Space memory re-key (#1230)", .serialized)
@MainActor
struct DesktopSpaceRekeyTests {
    private let stamp = DesktopIdentity(raw: "STAMP-RK")

    /// Space 10 carries the stamp; the topology answers to both
    /// its identity and its Mission Control number.
    private func stampedSnapshot() -> DesktopSnapshot {
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = [
            authoritySpace(
                10,
                display: "UUID-A",
                current: true,
                identity: stamp
            ),
            authoritySpace(11, display: "UUID-A"),
        ]
        return NativeSpaces.desktopSnapshot()
    }

    @Test("A number entry moves to the Desktop's stamp")
    func numberEntryRekeys() {
        defer { resetAuthorityOverrides() }
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        // Filed on the one call that saw the Desktop unstamped.
        core.desktopMemory.virtualSpaces[.number(1)] = SpaceID(2)
        let snapshot = stampedSnapshot()
        core.reconcileDesktopSpaceMemory(in: snapshot)
        #expect(
            core.desktopMemory.virtualSpaces[.identity(stamp)]
                == SpaceID(2)
        )
        #expect(core.desktopMemory.virtualSpaces[.number(1)] == nil)
    }

    /// The whole point: after the re-key the Desktop returns to
    /// the Space it was left on rather than stepping over it.
    @Test("A re-keyed Desktop returns to its own Space")
    func rekeyedDesktopReturnsToItsSpace() {
        defer { resetAuthorityOverrides() }
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.ensureSpace(SpaceID(3))
        core.desktopMemory.virtualSpaces[.number(1)] = SpaceID(2)
        let snapshot = stampedSnapshot()
        core.reconcileDesktopSpaceMemory(in: snapshot)
        #expect(
            core.virtualSpaceTarget(
                for: .identity(stamp),
                in: snapshot
            ) == SpaceID(2)
        )
    }

    /// The WIRING, which the cases above cannot see: they call
    /// the re-key directly, so deleting its call site leaves them
    /// green. `stampedDesktopSnapshot` is the ONE reading every
    /// switch takes, and where #1147 put the binding re-key for
    /// the same reason — a caller that forgot would leave an
    /// entry keyed by a number for the session with nothing to
    /// say so.
    @Test("The one snapshot re-keys the Space memory")
    func theSnapshotRekeys() {
        defer { resetAuthorityOverrides() }
        let core = makeAuthorityCore()
        core.desktopMemory.virtualSpaces[.number(1)] = SpaceID(2)
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = [
            authoritySpace(
                10,
                display: "UUID-A",
                current: true,
                identity: stamp
            ),
            authoritySpace(11, display: "UUID-A"),
        ]
        _ = core.stampedDesktopSnapshot()
        #expect(
            core.desktopMemory.virtualSpaces[.identity(stamp)]
                == SpaceID(2)
        )
        #expect(core.desktopMemory.virtualSpaces[.number(1)] == nil)
    }

    /// A record whose Desktop this topology cannot name stays
    /// DORMANT — absence is never proof (#1147).
    @Test("A dormant entry is left alone")
    func dormantEntrySurvives() {
        defer { resetAuthorityOverrides() }
        let core = makeAuthorityCore()
        let absent = DesktopIdentity(raw: "STAMP-GONE")
        core.desktopMemory.virtualSpaces[.identity(absent)] =
            SpaceID(9)
        let snapshot = stampedSnapshot()
        core.reconcileDesktopSpaceMemory(in: snapshot)
        #expect(
            core.desktopMemory.virtualSpaces[.identity(absent)]
                == SpaceID(9)
        )
    }

    /// Both keys naming one Desktop: the number entry is dropped
    /// rather than moved over the stamped one, which is the
    /// shared `keyMoves` drop clause.
    @Test("A number entry beside its own stamp is dropped")
    func numberBesideItsStampIsDropped() {
        defer { resetAuthorityOverrides() }
        let core = makeAuthorityCore()
        core.desktopMemory.virtualSpaces[.identity(stamp)] =
            SpaceID(3)
        core.desktopMemory.virtualSpaces[.number(1)] = SpaceID(2)
        let snapshot = stampedSnapshot()
        core.reconcileDesktopSpaceMemory(in: snapshot)
        #expect(
            core.desktopMemory.virtualSpaces[.identity(stamp)]
                == SpaceID(3)
        )
        #expect(core.desktopMemory.virtualSpaces[.number(1)] == nil)
    }
}
