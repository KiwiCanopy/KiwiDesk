import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The bar sweep judges a fit it sent and the app has not echoed
/// (#3157), and that read must not clear the #1091 refusal memo:
/// a pass inside the echo grace found the ask "already fitted",
/// forgot the memo, and the pass after it asked again, forever,
/// of an app that refuses the size.
@Suite("Float fit memo survives the echo grace", .serialized)
@MainActor
struct FloatFitMemoGraceTests {
    private static let window = WindowID(1)

    private func makeBarredCore(frame: CGRect) -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.tiler.allScreenBounds = { [screen.frame] }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 900_001,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.barEdge = .top
        core.tiler.settings.kiwishelf.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return core
    }

    @Test(
        "A refused fit is not asked again after a pass in the grace",
        .enabled(if: NSScreen.main != nil)
    )
    func refusalHolds() throws {
        let screen = try #require(NSScreen.screens.first)
        // Taller than the region below the bar: the sweep owes a
        // size fit, which this app never answers.
        let oversized = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY + 40,
            width: 500,
            height: screen.frame.height - 40
        )
        let core = try #require(makeBarredCore(frame: oversized))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        try #require(
            core.spaceBars.shownStrips.first != nil,
            "no bar painted — the clause would pass vacuously"
        )
        core.clampFloatsClearOfBars()
        let fit = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the sweep sent no fit"
        )
        #expect(fit.height < oversized.height)
        // A pass inside the grace judges the unechoed fit.
        core.clampFloatsClearOfBars()
        // The grace lapses with no echo: the app refused.
        core.tiler.clearInstantTarget(Self.window)
        core.clampFloatsClearOfBars()
        #expect(core.tiler.recentInstantTarget(Self.window) == nil)
    }
}
