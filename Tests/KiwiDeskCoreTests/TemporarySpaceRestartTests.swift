import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Temporary Spaces across a restart and an unplug (#1790): every
/// snapshot carries one with its pin, boot re-creates it ahead of
/// the replay only under the arrangement it was taken in, and a
/// departing screen's temporary Space is held and comes back
/// temporary. Process A is `HeldSpaceDesk`'s docked desk.
@Suite("Temporary Spaces across a restart (#1790)", .serialized)
@MainActor
struct TemporarySpaceRestartTests {
    private let desk = HeldSpaceDesk()
    private let scratch = SpaceID(9)

    private func crossed(_ snapshot: StateSnapshot) throws -> StateSnapshot {
        try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
    }

    /// Docked, window 12 moved into a temporary 9 pinned to the DELL.
    private func withScratch() throws -> KiwiCore {
        let core = try desk.docked()
        core.execute(
            "move_to_space",
            args: [.string(scratch.raw), .number(12)]
        )
        core.execute(
            "pin_space_to_display",
            args: [.string(scratch.raw), .string(desk.dell.fingerprint)]
        )
        #expect(core.isTemporary(scratch))
        return core
    }

    /// Process B on the docked desk under `profile`, window 12
    /// scanned into Space 1, then the boot tail from `session`.
    private func boot(
        from a: KiwiCore,
        profile: String,
        session: StateSnapshot
    ) -> KiwiCore {
        let core = makeTestCore(configDirectory: a.configDirectory)
        core.handle(.displaysChanged([desk.builtIn, desk.dell]))
        core.execute("load_profile", args: [.string(profile)])
        core.state.windows.upsert(desk.window(12))
        core.state.workspaces.add(WindowID(12), to: SpaceID(1))
        core.arrangeBootDesk(session: session)
        return core
    }

    @Test("every capture carries it, with its pin")
    func recordCarriesIt() throws {
        let core = try withScratch()
        for inPlace in [false, true] {
            let session = try crossed(core.sessionSnapshot(inPlace: inPlace))
            let record = try #require(
                session.spaces.first { $0.id == scratch.raw }
            )
            #expect(record.temporary?.armed == true)
            #expect(record.temporary?.pin == desk.dell.fingerprint)
            let declared = session.spaces.first { $0.id == "1" }
            #expect(declared?.temporary == nil)
        }
    }

    @Test("an unreadable record costs only itself")
    func unreadableRecord() throws {
        let json = """
            {"id":"9","mode":"bsp","windows":[12],"temporary":7}
            """
        let record = try JSONDecoder().decode(
            StateSnapshot.SpaceRecord.self,
            from: Data(json.utf8)
        )
        #expect(record.temporary == nil)
        #expect(record.windows == [12])
    }

    @Test("a restart under the same arrangement brings it back")
    func restartKeepsIt() throws {
        let a = try withScratch()
        let b = boot(
            from: a,
            profile: "desk",
            session: try crossed(a.sessionSnapshot())
        )
        #expect(b.isTemporary(scratch))
        #expect(b.state.workspaces[scratch]?.windows == [WindowID(12)])
        #expect(b.spacePins[scratch] == desk.dell.fingerprint)
    }

    @Test("a restart into another arrangement is a switch")
    func restartElsewhereDrops() throws {
        let a = try withScratch()
        try a.profiles.write(
            desk.profile(
                "other",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: [SpaceID(1), SpaceID(2)]
            )
        )
        let session = try crossed(a.sessionSnapshot())
        let b = boot(from: a, profile: "other", session: session)
        #expect(b.state.workspaces[scratch] == nil)
        #expect(b.state.temporarySpaces.isEmpty)
    }

    @Test("an unplug holds it, and the replug brings it back temporary")
    func unplugHoldsAndReturns() throws {
        let core = try withScratch()
        core.handle(.displaysChanged([desk.builtIn]))
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == scratch }
        )
        #expect(held.value.isTemporary)
        #expect(core.state.temporarySpaces.isEmpty, "never both")
        core.handle(.displaysChanged([desk.builtIn, desk.dell]))
        #expect(core.profiles.currentName == "desk")
        #expect(core.state.heldSpaces.isEmpty)
        let back = try #require(
            core.state.workspaces.allSpaces.first {
                $0.windows == [WindowID(12)]
            }
        )
        #expect(core.isTemporary(back.id))
        #expect(core.spacePins[back.id] == desk.dell.fingerprint)
    }

    @Test("an empty one on a departing screen is dropped")
    func emptyDeparturesDrop() throws {
        let core = try withScratch()
        core.state.workspaces.add(WindowID(12), to: SpaceID(4))
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.state.workspaces[scratch] == nil)
        #expect(!core.state.heldSpaces.values.contains { $0.name == scratch })
    }
}
