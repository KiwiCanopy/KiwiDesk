import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_space_to_display` / `pin_space_to_display` (multi-monitor
/// Lua/CLI API). Two synthetic displays laid out side by side, so
/// positional index resolves by frame order (leftmost = 1).
@Suite("Space→display commands", .serialized)
@MainActor
struct SpaceDisplayCommandTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-core-\(UUID().uuidString)"
                )
        )
    }

    private let d1 = DisplayID(10)
    private let d2 = DisplayID(20)

    private func withTwoDisplays(_ core: KiwiCore) {
        core.state.apply(
            .displaysChanged([
                Display(
                    id: d1,
                    name: "Left",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 1920,
                        height: 1080
                    )
                ),
                Display(
                    id: d2,
                    name: "Right",
                    frame: CGRect(
                        x: 1920,
                        y: 0,
                        width: 1920,
                        height: 1080
                    )
                ),
            ])
        )
    }

    @Test("move_space_to_display assigns by positional index")
    func moveByIndex() {
        let core = makeCore()
        withTwoDisplays(core)
        // Index 2 = the right monitor (frame order, main-first).
        let r = core.execute(
            "move_space_to_display",
            args: [.string("5"), .number(2)]
        )
        #expect(r.isSuccess)
        #expect(core.state.workspaces.display(of: SpaceID("5")) == d2)
    }

    @Test("move_space_to_display resolves a display by name")
    func moveByName() {
        let core = makeCore()
        withTwoDisplays(core)
        let r = core.execute(
            "move_space_to_display",
            args: [.string("5"), .string("Right")]
        )
        #expect(r.isSuccess)
        #expect(core.state.workspaces.display(of: SpaceID("5")) == d2)
    }

    @Test("move_space_to_display rejects an unknown display")
    func moveUnknownDisplay() {
        let core = makeCore()
        withTwoDisplays(core)
        let r = core.execute(
            "move_space_to_display",
            args: [.string("5"), .number(9)]
        )
        #expect(!r.isSuccess)
    }

    @Test("pin_space_to_display pins by fingerprint and resolves")
    func pinResolves() {
        let core = makeCore()
        withTwoDisplays(core)
        let fingerprint = Display(
            id: d2,
            name: "Right",
            frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        ).fingerprint
        let r = core.execute(
            "pin_space_to_display",
            args: [.string("5"), .number(2)]
        )
        #expect(r.isSuccess)
        #expect(core.spacePins[SpaceID("5")] == fingerprint)
        // The pin resolves the space onto that display.
        #expect(core.state.workspaces.display(of: SpaceID("5")) == d2)
    }

    @Test("pin overrides a prior Main-role assignment")
    func pinDropsMain() {
        let core = makeCore()
        withTwoDisplays(core)
        core.mainSpaces.insert(SpaceID("5"))
        _ = core.execute(
            "pin_space_to_display",
            args: [.string("5"), .number(1)]
        )
        #expect(!core.mainSpaces.contains(SpaceID("5")))
        #expect(core.state.workspaces.display(of: SpaceID("5")) == d1)
    }

    @Test("both verbs need a space id")
    func requireSpaceID() {
        let core = makeCore()
        withTwoDisplays(core)
        #expect(
            !core.execute("move_space_to_display", args: []).isSuccess
        )
        #expect(
            !core.execute("pin_space_to_display", args: []).isSuccess
        )
    }
}
