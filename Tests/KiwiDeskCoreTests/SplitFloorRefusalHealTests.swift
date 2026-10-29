import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The split floor heal counts one refusal (#2774): a stack member
/// that refused a width once — never corroborated, the way KiwiDesk
/// Settings answered 720 on device — moves the master ratio so the
/// zone draws it, where the corroborated reading left it
/// overlapping the master. Display and `min_window_size` pinned
/// (#531, #660).
@Suite("Split floor heal counts a refusal (#2774)", .serialized)
@MainActor
struct SplitFloorRefusalHealTests {
    /// Master w1 and stack w2 in a Stack Space on a pinned
    /// 1200×800 display.
    private func makeCore() -> (KiwiCore, SpaceID) {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-split-refusal-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_100 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    private func ratio(_ core: KiwiCore, _ space: SpaceID) -> Double {
        core.tiler.settings.resolvedStack(
            for: core.state.workspaces[space]!
        ).masterRatio
    }

    @Test("One refusal moves the master ratio")
    func refusalHealsTheMasterRatio() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore()
        core.retile()
        let before = ratio(core, space)
        core.tiler.boundLearner.bounds[WindowID(2)] = .init(width: [
            .init(asked: 400, answered: 700)
        ])
        core.retile()
        #expect(ratio(core, space) < before)
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[WindowID(2)]
        )
        #expect(frame.width >= 700)
    }

    @Test("A snap's few points move nothing")
    func snapNoiseKeepsTheRatio() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore()
        core.retile()
        let before = ratio(core, space)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let width = try #require(frames[WindowID(2)]).width
        let margin = EffectiveSizeBound.refusalMargin
        core.tiler.boundLearner.bounds[WindowID(2)] = .init(width: [
            .init(asked: width + 1 - margin, answered: width + 1)
        ])
        core.retile()
        #expect(ratio(core, space) == before)
    }
}
