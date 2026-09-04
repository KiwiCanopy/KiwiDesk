import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop with no memory picks a Space no OTHER Desktop is
/// showing (#1230), so a fresh Desktop stops landing on a Space
/// whose windows are all somewhere else — the state the issue
/// opens with, observed 2026-09-03 and reproduced on the device
/// 2026-09-04 (`active_space: "1"` on Desktop 2 while every one
/// of Space 1's windows sat in the away ledger on Desktop 1).
///
/// The remembered path is `DesktopMemoryTests`'; this suite is
/// the FALLBACK's three obligations.
///
/// Serialized, and the fixture is `DesktopAuthorityFixture.swift`.
@Suite("First-visit Space pick (#1230)", .serialized)
@MainActor
struct DesktopFirstVisitTests {
    private func core() -> KiwiCore {
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        return makeAuthorityCore()
    }

    /// A Desktop the snapshot lists, so its memory counts.
    private var present: DesktopKey { .number(1) }
    /// One it does not, so its memory is dormant.
    private var absent: DesktopKey { .number(99) }

    @Test("A fresh Desktop steps over a Space in use")
    func picksAnUnusedSpace() {
        defer { resetAuthorityOverrides() }
        let core = core()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.ensureSpace(SpaceID(3))
        let snapshot = authoritySnapshot()
        // Space 1 is active; Desktop 1 is remembered on Space 2.
        core.desktopMemory.virtualSpaces[present] = SpaceID(2)
        #expect(
            core.virtualSpaceTarget(for: .number(4), in: snapshot)
                == SpaceID(3)
        )
    }

    /// **TOTAL**: the switch arm reads
    /// `if let key, let target = virtualSpaceTarget(...)`, and
    /// `oweReturningFocus` is reached for every user-Desktop
    /// arrival only because this answers. A nil would silently
    /// skip the activate, the focus debt, the retile and the
    /// emit — so an exhausted pick falls back rather than
    /// returning nothing.
    @Test("An exhausted pick still answers")
    func exhaustedPickIsTotal() {
        defer { resetAuthorityOverrides() }
        let core = core()
        let snapshot = authoritySnapshot()
        // One Space, and it is the active one — nothing is free.
        #expect(core.state.workspaces.allSpaces.count == 1)
        #expect(
            core.virtualSpaceTarget(for: .number(4), in: snapshot)
                != nil
        )
    }

    /// A record whose Desktop no reading names stays DORMANT
    /// (#1147 — an unplugged screen's Desktops come back with
    /// their stamps). Counting one as "in use" would retire a
    /// Space nothing is showing, and on a machine that has ever
    /// had a second screen it would retire several.
    @Test("A dormant Desktop's memory does not reserve a Space")
    func dormantMemoryReservesNothing() {
        defer { resetAuthorityOverrides() }
        let core = core()
        core.state.workspaces.ensureSpace(SpaceID(2))
        let snapshot = authoritySnapshot()
        core.desktopMemory.virtualSpaces[absent] = SpaceID(2)
        // Space 2 is spoken for only by a Desktop the topology no
        // longer lists, so it is free.
        #expect(
            core.virtualSpaceTarget(for: .number(4), in: snapshot)
                == SpaceID(2)
        )
    }

    /// The pick chooses from the PROFILE's declared Spaces, not
    /// every live one: a Space created live (`create_space`)
    /// belongs to no profile, and landing a fresh Desktop on one
    /// would replace this issue's confusion with a new one.
    @Test("The pick chooses from the profile's declared Spaces")
    func picksOnlyDeclaredSpaces() throws {
        defer { resetAuthorityOverrides() }
        let core = core()
        core.state.workspaces.ensureSpace(SpaceID(2))
        // A monitor set is required: the decoder refuses a
        // profile without one, and a `try?` read would then
        // silently fall through the clause under test.
        try core.profiles.save(
            Profile(
                name: "P",
                monitorSets: [
                    MonitorSet(
                        monitors: ["Screen:100x100"],
                        spaceMonitorMap: [:]
                    )
                ],
                spaces: [SpaceID(1)],
                spaceModes: [SpaceID(1): .bsp],
                settings: TilingSettings()
            )
        )
        let snapshot = authoritySnapshot()
        // Space 2 is live but undeclared, so it is not a
        // candidate — and with nothing free the pick falls back
        // rather than answering nil.
        #expect(
            core.virtualSpaceTarget(for: .number(4), in: snapshot)
                == SpaceID(1)
        )
    }
}
