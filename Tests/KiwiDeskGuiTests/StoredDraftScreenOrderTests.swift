import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A stored profile's draft is numbered in that profile's own screen
/// order, never the live one's (#3647): its pins read onto the
/// screens and a placement writes back through the set it holds, so a
/// Save leaves its Spaces where they were.
@Suite("A stored draft reads its own screen order (#3647)", .serialized)
@MainActor
struct StoredDraftScreenOrderTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647-gui-\(UUID().uuidString)")
        )
    }

    /// A on the left, B on the right.
    private func connect(_ core: KiwiCore) {
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        for (index, name) in ["A", "B"].enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: name,
                    frame: CGRect(
                        x: CGFloat(index) * 100,
                        y: 0,
                        width: 100,
                        height: 100
                    )
                )
            )
        }
    }

    @Test("a stored draft reads and writes in its own order")
    func storedDraftTakesItsOrder() throws {
        let core = makeCore()
        connect(core)
        // Its order runs right to left, against the live suggestion.
        try core.profiles.write(
            Profile(
                name: "Other",
                monitorSets: [
                    MonitorSet(monitors: ["B:100x100", "A:100x100"])
                ],
                spaceMonitorMap: ["2": ScreenSlotKey(number: 1)!],
                spaces: ["1", "2", "3"],
                spaceModes: ["1": .bsp, "2": .bsp, "3": .bsp],
                settings: TilingSettings()
            )
        )
        #expect(core.liveScreenOrder.fingerprints.first == "A:100x100")
        let model = makeTestModel(core: core)
        model.target = .storedProfile("Other")
        model.reload()
        #expect(model.target == .storedProfile("Other"))
        #expect(model.pin(of: "2") == "B:100x100")
        model.place("3", .screen("A:100x100"))
        #expect(model.config.spacePins["3"] == ScreenSlotKey(number: 2))
    }
}
