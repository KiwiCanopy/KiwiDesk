import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-floatmono-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: dir)
}

/// Monocle space with `count` windows on space "1", horizontal
/// orientation, plus a float parked right of the shared frame.
/// Returns the float's id.
@MainActor
private func makeMonocleWithFloat(
    _ core: KiwiCore,
    tiled count: Int
) -> WindowID {
    for id in 1...(count + 1) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 1,
                    appName: "A"
                )
            )
        )
    }
    core.execute(
        "set_mode",
        args: [.string("1"), .string("monocle")]
    )
    core.execute(
        "monocle.set_orientation",
        args: [.string("horizontal")]
    )
    let floatID = WindowID(UInt32(count + 1))
    core.state.windows.setFloating(floatID, true)
    let shared = core.tiler.calculatedFrames(
        state: core.state
    )[WindowID(1)]!
    core.state.apply(
        .windowMoved(
            floatID,
            CGRect(
                x: shared.maxX + 40,
                y: shared.midY - 100,
                width: 240,
                height: 200
            )
        )
    )
    return floatID
}

/// Monocle's along-axis seams into the float tier (#488 review
/// round 2): the lone-window fall-through and the
/// end-without-wrap fall-through.
@Suite("Focus float tier, monocle axis (#488)", .serialized)
@MainActor
struct FocusFloatTierMonocleTests {
    @Test("A lone monocle window reaches a float along the axis")
    func loneWindowReachesFloat() {
        let core = makeCore()
        let floatID = makeMonocleWithFloat(core, tiled: 1)
        core.state.workspaces.focus(
            WindowID(1),
            in: SpaceID("1")
        )
        // Pre-fix, the count guard swallowed the press with a
        // silent .ok before either tier could answer.
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(
            core.activeSpace?.focused == floatID
        )
        // Away from the float there is no candidate: the press
        // is an honest dead end, not a silent success.
        core.state.workspaces.focus(
            WindowID(1),
            in: SpaceID("1")
        )
        #expect(
            !core.execute("focus", args: [.string("left")])
                .isSuccess
        )
    }

    @Test("An unwrapped monocle end reaches a float on the axis")
    func unwrappedEndReachesFloat() {
        let core = makeCore()
        let floatID = makeMonocleWithFloat(core, tiled: 2)
        core.execute(
            "monocle.set_wrap_focus",
            args: [.bool(false)]
        )
        // w2 is the carousel's last window; with wrap off the
        // end step falls through both the cycle and the tied
        // shared-frame tiled search into the float tier.
        core.state.workspaces.focus(
            WindowID(2),
            in: SpaceID("1")
        )
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(
            core.activeSpace?.focused == floatID
        )
    }
}
