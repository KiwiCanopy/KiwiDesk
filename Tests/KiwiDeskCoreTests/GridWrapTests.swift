import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A focus step past a Grid's top row wraps to its last row
/// (#3207): seven windows lay out in rows of 3, 3 and a full-width
/// 1, and ↑ from the top row lands on the full-width window.
@Suite("Grid wrap (#3207)", .serialized)
@MainActor
struct GridWrapTests {
    private func gridOfSeven() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwidesk-grid-wrap-\(UUID())")
        )
        // Tall enough that three rows clear `min_window_size`.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 1300)
        }
        core.execute("set_mode", args: [.string("1"), .string("grid")])
        // Three columns, three rows: 3, 3 and a full-width last row.
        core.execute(
            "grid.set_dimensions",
            args: [.number(3), .number(3)]
        )
        for id in UInt32(1)...7 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)",
                        frame: CGRect(x: 0, y: 25, width: 400, height: 300)
                    )
                )
            )
        }
        core.retile()
        // The height above is reasoned from this floor (tests.md).
        let floor = core.tiler.settings.minWindowSize(
            for: .grid,
            in: SpaceID("1")
        )
        #expect(floor.height == 300)
        return core
    }

    /// The slots the layout laid out, which navigation reads.
    private func frames(_ core: KiwiCore) -> [WindowID: CGRect] {
        core.shownSlots()
    }

    @Test("↑ from every top-row window wraps to the last row")
    func upWrapsToTheLastRow() throws {
        for mode in ["this_screen", "all_screens"] {
            for start in UInt32(1)...3 {
                let core = gridOfSeven()
                core.execute("set_focus_wrap", args: [.string(mode)])
                let laid = frames(core)
                // The last row's one window spans the width.
                let bottom = try #require(
                    laid.first { $0.value.width > 1000 }?.key,
                    "\(laid)"
                )
                core.state.apply(.windowFocused(WindowID(start)))
                let top = try #require(laid[WindowID(start)])
                #expect(
                    laid.values.allSatisfy { $0.minY >= top.minY - 1 },
                    "\(mode) \(start) starts in the top row: \(laid)"
                )
                #expect(
                    core.navigate([.string("up")], swapping: false)
                        .isSuccess
                )
                #expect(
                    core.state.workspaces.lastFocused == bottom,
                    "\(mode) from \(start): \(laid)"
                )
            }
        }
    }
}
