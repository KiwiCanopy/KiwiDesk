import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space's own minimum window size across a switch (#2422). The
/// map is config, as `gap.override` is: a held Space's renumber
/// carries neither to its new number, the claiming arrangement's
/// Space of that name does not inherit them, and going home brings
/// both back with the arrangement that declared them.
@MainActor
@Suite("Per-Space minimum window size across a hold")
struct MinWindowSizeOverrideHoldTests {
    private let desk = HeldSpaceDesk()
    private let three = SpaceID(3)

    @Test("a renumbered hold leaves the value home, and it returns")
    func holdLeavesItHome() throws {
        let core = try desk.docked()
        var deskProfile = try core.profiles.read(name: "desk")
        deskProfile.settings.minWindowSizeOverride[three] = 200
        deskProfile.settings.gapsOverride[three] = .uniform(4)
        try core.profiles.write(deskProfile)
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.tiler.settings.minWindowSizeOverride[three] == 200)
        try core.profiles.write(
            desk.profile(
                "pair",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: [SpaceID(1), SpaceID(2)]
            )
        )
        core.execute("load_profile", args: [.string("pair")])
        #expect(core.state.heldSpaces[three]?.name == three)
        try core.profiles.write(
            desk.profile(
                "claim",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: [SpaceID(1), SpaceID(2), three]
            )
        )
        core.execute("load_profile", args: [.string("claim")])
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == three }?.key
        )
        #expect(held != three)
        let live = core.tiler.settings
        for id in [held, three] {
            #expect(live.minWindowSizeOverride[id] == nil)
            #expect(live.gapsOverride[id] == nil)
        }
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.state.heldSpaces.isEmpty)
        #expect(desk.members(core, 3) == desk.ids([10, 11]))
        #expect(core.tiler.settings.minWindowSizeOverride[three] == 200)
        #expect(core.tiler.settings.gapsOverride[three] == .uniform(4))
    }
}
