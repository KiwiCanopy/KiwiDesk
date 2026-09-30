import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Both Keep Layout in Profile rows — the status item's and a
/// Space chip's — arm on the same verdict (#1790): they call the
/// one Keep, so a Space set only one of them sees would grey one
/// row above a Keep the other offers.
@Suite("Keep arming parity", .serialized)
@MainActor
struct KeepArmingParityTests {
    @Test("a new Space arms the status item's Keep as the chip's")
    func bothRowsArm() {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-keep-parity-\(UUID())")
        )
        let display = Display(
            id: DisplayID(7),
            name: "Desk",
            frame: CGRect(x: 0, y: 0, width: 1000, height: 600)
        )
        core.state.workspaces.upsertDisplay(display)
        core.state.workspaces.assign(SpaceID("1"), to: display.id)
        core.state.workspaces.activate(SpaceID("1"))
        let profile = core.buildProfile(name: "p", modes: nil)
        core.profiles.becameLive(profile, fits: true)
        #expect(!LayoutMenuInfo.current(from: core).anyScreenHasDrifted)
        core.execute("create_space", args: [.string("2")])
        #expect(core.spaceSetDrifted)
        #expect(LayoutMenuInfo.current(from: core).anyScreenHasDrifted)
    }
}
