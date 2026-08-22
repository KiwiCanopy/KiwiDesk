import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Resize minimum size limits & refusal feedback (#933)")
@MainActor
struct ResizeSizeLimitFeedbackTests {
    @Test("EffectiveSizeBound extracts learned minWidth and minHeight")
    func sizeBoundDerivesMinimums() {
        let bound = EffectiveSizeBound(
            width: [
                EffectiveSizeBound.Axis(asked: 300, answered: 500),
                EffectiveSizeBound.Axis(asked: 200, answered: 500),
            ],
            height: [
                EffectiveSizeBound.Axis(asked: 250, answered: 400)
            ]
        )
        #expect(bound.minWidth == 500)
        // A single refused ask never corroborates a floor —
        // grid noise reads exactly like it (#933/#677).
        #expect(bound.minHeight == nil)

        let emptyBound = EffectiveSizeBound(
            width: [] as [EffectiveSizeBound.Axis],
            height: []
        )
        #expect(emptyBound.minWidth == nil)
        #expect(emptyBound.minHeight == nil)

        // Asked 600, answered 400 is a ceiling, not a floor:
        let ceilingBound = EffectiveSizeBound(
            width: [EffectiveSizeBound.Axis(asked: 600, answered: 400)]
        )
        #expect(ceilingBound.minWidth == nil)
    }

    @Test("Stack resize clamps against learned size bound")
    func stackResizeClampsAtLearnedMin() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-stack-resize-limit-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
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

        // Seed learned bound: Window 1 cannot shrink below 500 pt
        // Two DISTINCT asks converging on 500: the floor is
        // only believed corroborated (#933).
        for asked in [CGFloat(300), CGFloat(240)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 500, height: 800)
                )
            }
        }

        // Attempting to shrink past 500pt should clamp
        let res = core.execute(
            "resize",
            args: [.string("x"), .number(-800)]
        )
        #expect(res.isSuccess)
        let spaceObj = core.state.workspaces[space]!
        let stack = core.tiler.settings.resolvedStack(for: spaceObj)
        let ratio = stack.masterRatio
        // At 1200 width, 500 min size means masterRatio is at least ~0.416
        #expect(ratio >= 0.40)
    }

    @Test("Track resize clamps against learned size bound")
    func trackResizeClampsAtLearnedMin() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-track-resize-limit-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)

        // Two DISTINCT asks converging on 500: the floor is
        // only believed corroborated (#933).
        for asked in [CGFloat(300), CGFloat(240)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 500, height: 800)
                )
            }
        }

        let res = core.execute(
            "resize",
            args: [.string("x"), .number(-800)]
        )
        #expect(res.isSuccess)
        let weight =
            core.state.workspaces[space]?.trackWeights[WindowID(1)] ?? 1.0
        // Weight is clamped at the 500pt floor rather than dropping to 0.1
        #expect(weight >= 0.5)
    }

    @Test("BSP resize clamps against learned size bound")
    func bspResizeClampsAtLearnedMin() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-bsp-resize-limit-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("bsp")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)

        // Two DISTINCT asks converging on 500: the floor is
        // only believed corroborated (#933).
        for asked in [CGFloat(300), CGFloat(240)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 500, height: 800)
                )
            }
        }

        let res = core.execute(
            "resize",
            args: [.string("x"), .number(-800)]
        )
        #expect(res.isSuccess)
        let bsp = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        )
        #expect(bsp.splitRatioH >= 0.40)
    }

    @Test("Floating resize clamps against learned size bound")
    func floatingResizeClampsAtLearnedMin() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-float-resize-limit-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "FloatApp",
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400),
                    isFloating: true
                )
            )
        )
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)

        for asked in [CGFloat(300), CGFloat(240)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 400)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 480, height: 400)
                )
            }
        }
        var appliedFrame: CGRect?
        core.tiler.settings.animations.onWindowResize = true
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { _, frame, _ in
            appliedFrame = frame
        }

        let res = core.execute(
            "resize",
            args: [.string("x"), .number(-300)]
        )
        #expect(res.isSuccess)
        #expect(appliedFrame?.width == 480)
    }
}
