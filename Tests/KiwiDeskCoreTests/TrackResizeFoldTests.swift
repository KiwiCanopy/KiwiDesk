import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The track resize clamp reasons over the partition the render
/// DRAWS (#1488): under the geometric fold the per-marker one
/// put a share the screen never showed under its floor and
/// refused a legal grow — and called a folded column's along
/// axis "nothing to divide". Display and `min_window_size`
/// pinned (#531, #660).
@Suite("Track resize folds like the render (#1488)", .serialized)
@MainActor
struct TrackResizeFoldTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    /// Three own-track windows on a pinned 1200×800 display,
    /// w1 carrying a corroborated 650 pt floor — 650 + 300 + 300
    /// and two gaps do not fit, so the automatic count folds w2
    /// and w3 into one column — and stored weights 2 : 1 : 2
    /// from an earlier three-track arrangement.
    private func makeCore() -> (KiwiCore, SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-resize-fold-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        for asked in [CGFloat(500), CGFloat(450)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w1,
                    size: CGSize(width: asked, height: 700)
                )
                core.tiler.boundLearner.observe(
                    w1,
                    currentSize: CGSize(width: 650, height: 700),
                    settledRead: true
                )
            }
        }
        #expect(core.tiler.sizeBound(for: w1)?.minWidth == 650)
        core.state.workspaces.withSpace(space) {
            $0.trackWeights[w1] = 2
            $0.trackWeights[w2] = 1
            $0.trackWeights[w3] = 2
        }
        core.state.workspaces.focus(w2, in: space)
        core.retile()
        // The render's fold: w2 and w3 share one column.
        let frames = core.tiler.calculatedFrames(state: core.state)
        #expect(frames[w2]?.minX == frames[w3]?.minX)
        return (core, space)
    }

    @Test("A grow the drawn partition admits is not refused")
    func growAcrossTheFoldIsAdmitted() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore()
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        // Drawn: w1 at 2/3 of the span (~790), the column at 1/3.
        // A 100 pt grow leaves w1 ~690, above its 650 floor. The
        // per-marker model put w1 at 2/5 (~470), under it.
        #expect(
            core.execute(
                "resize",
                args: [.string("x"), .number(100)]
            ).isSuccess
        )
        #expect(refusals.isEmpty)
        let weights = try #require(
            core.state.workspaces[space]?.trackWeights
        )
        #expect((weights[w2] ?? 1) > 1)
    }

    @Test("A folded column divides along its axis")
    func folded_column_divides_along() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore()
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        // w2 shares its drawn column with w3, so its along-axis
        // share divides something — the per-marker model saw a
        // one-window track and refused "nothing to divide".
        #expect(
            core.execute(
                "resize",
                args: [.string("y"), .number(50)]
            ).isSuccess
        )
        #expect(refusals.isEmpty)
        let shares = try #require(
            core.state.workspaces[space]?.stackWeights
        )
        #expect((shares[w2] ?? 1) > 1)
    }
}
