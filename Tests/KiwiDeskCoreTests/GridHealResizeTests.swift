import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Grid's `resize` solves against the healed shape (#2687): a learned
/// floor that drops a column from the render drops it from the press
/// too, so the press moves an edge the screen draws. Display, gaps
/// and floor are pinned (#531); no locale is read.
@Suite("Grid heal reaches the resize", .serialized)
@MainActor
struct GridHealResizeTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-grid-heal-\(UUID().uuidString)"
                )
        )
        // 1220 × 820 less 10-pt outer gaps leaves a 1200 × 800 grid
        // with 20-pt inner gaps: three 300-pt columns fit.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1220, height: 820)
        }
        core.tiler.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(top: 10, bottom: 10, left: 10, right: 10),
            inner: Gaps.Inner(horizontal: 20, vertical: 20)
        )
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.tiler.animation.isEnabled = false
        return core
    }

    /// Two windows in a rigid 3 × 1 grid, the first focused, the
    /// second with a corroborated 500-pt learned minimum width.
    @discardableResult
    private func healedGrid(_ core: KiwiCore) -> SpaceID {
        core.execute("grid.set_type", args: [.string("rigid")])
        core.execute(
            "grid.set_dimensions",
            args: [.number(3), .number(1)]
        )
        for id in UInt32(1)...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(900_000 + Int32(id)),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("grid")]
        )
        for asked in [CGFloat(400), CGFloat(350)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(2),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(2),
                    currentSize: CGSize(width: 500, height: 800),
                    settledRead: true
                )
            }
        }
        #expect(core.tiler.sizeBound(for: WindowID(2))?.minWidth == 500)
        core.state.workspaces.focus(WindowID(1), in: space)
        core.retile()
        return space
    }

    private func width(_ core: KiwiCore, _ id: UInt32) -> CGFloat {
        core.tiler.calculatedFrames(state: core.state)[WindowID(id)]?
            .width ?? 0
    }

    @Test("A press moves the edge of the healed two-column grid")
    func pressSolvesTheHealedShape() {
        let core = makeCore()
        healedGrid(core)
        // 1200 / (500 + 20) fits two columns, not three.
        let half: CGFloat = (1200 - 20) / 2
        #expect(abs(width(core, 1) - half) < 0.5)
        #expect(abs(width(core, 2) - half) < 0.5)
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(60)]
        )
        #expect(response.isSuccess)
        #expect(abs(width(core, 1) - (half + 60)) < 0.5)
        #expect(abs(width(core, 2) - (half - 60)) < 0.5)
    }
}
