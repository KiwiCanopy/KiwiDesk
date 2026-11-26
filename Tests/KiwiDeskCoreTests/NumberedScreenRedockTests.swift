import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The live profile moved onto a same-count setup it does not hold
/// keeps no apply, so its monitor-change arm re-numbers its pins
/// there, left to right (#3647 ▸ lane 2): the count's default
/// through `.countDefault`, any other profile of a Lua-owned config
/// through `.none`.
@Suite("Screen pins across a same-count re-dock (#3647)", .serialized)
@MainActor
struct NumberedScreenRedockTests {
    private func screen(_ id: UInt32, _ name: String, x: CGFloat) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: 0, width: 100, height: 100)
        )
    }

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647r-\(UUID().uuidString)")
        )
    }

    /// "Work" holds X–Y, Space 2 pinned to its Screen 2, loaded there.
    private func loadWork(_ core: KiwiCore, isDefault: Bool) throws {
        core.handle(
            .displaysChanged([
                screen(3, "X", x: 0), screen(4, "Y", x: 100),
            ])
        )
        try core.profiles.write(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["X:100x100", "Y:100x100"])
                ],
                spaceMonitorMap: ["2": ScreenSlotKey(number: 2)!],
                isDefault: isDefault,
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                settings: TilingSettings()
            )
        )
        try core.loadProfile(named: "Work")
        #expect(core.spacePins["2"] == "Y:100x100")
    }

    private func redock(_ core: KiwiCore) {
        core.handle(
            .displaysChanged([
                screen(1, "A", x: 0), screen(2, "B", x: 100),
            ])
        )
    }

    @Test("the live default re-numbers its pins on the new pair")
    func liveDefaultRenumbers() throws {
        let core = makeCore()
        try loadWork(core, isDefault: true)
        redock(core)
        #expect(core.profiles.currentName == "Work")
        #expect(core.spacePins["2"] == "B:100x100")
    }

    @Test("a live profile no rung picks re-numbers its pins too")
    func unmatchedLiveRenumbers() throws {
        let core = makeCore()
        try loadWork(core, isDefault: false)
        #expect(!core.isGuiManaged)
        redock(core)
        #expect(core.profiles.currentName == "Work")
        #expect(core.spacePins["2"] == "B:100x100")
    }
}
