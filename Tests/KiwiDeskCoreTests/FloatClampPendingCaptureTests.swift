import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The retile sweep judges a PENDING capture, never the state
/// frame it is leaving (#1177/#1352): the restore pass just sent
/// the window to the capture, and a fit of the stale frame would
/// land after the delivery and undo it — a scrolled-out column
/// under a left bar was pushed back to the bar edge instead of
/// taking its gather target. A capture under the bar is corrected
/// with the window, so the echo consumes it (#412).
@Suite("Float clamp judges the pending capture", .serialized)
@MainActor
struct FloatClampPendingCaptureTests {
    private static let window = WindowID(1)

    private func makeBarredCore(frame: CGRect) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.kiwishelf.edge = .top
        core.tiler.settings.kiwishelf.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateSpaceBar()
        return core
    }

    @Test(
        "A capture clear of the bar is left, whatever the state frame",
        .enabled(if: NSScreen.main != nil)
    )
    func clearCaptureIsLeft() throws {
        let screen = try #require(NSScreen.main)
        // The state frame sits under the strip; the capture does
        // not.
        let under = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY,
            width: 400,
            height: 300
        )
        let core = try #require(makeBarredCore(frame: under))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let painted = try #require(
            core.spaceBars.shownStrips.first?.1,
            "no bar painted — the clause would pass vacuously"
        )
        let capture = CGRect(
            x: screen.frame.minX + 100,
            y: painted.maxY + 200,
            width: 400,
            height: 300
        )
        core.tiler.seedStash(Self.window, frame: capture)
        core.clampFloatsClearOfBars()
        #expect(core.tiler.recentInstantTarget(Self.window) == nil)
        #expect(core.tiler.stashOriginal(Self.window) == capture)
    }

    @Test(
        "A capture under the bar is corrected with the window",
        .enabled(if: NSScreen.main != nil)
    )
    func coveredCaptureIsCorrected() throws {
        let screen = try #require(NSScreen.main)
        let clear = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY + 400,
            width: 400,
            height: 300
        )
        let core = try #require(makeBarredCore(frame: clear))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let painted = try #require(
            core.spaceBars.shownStrips.first?.1,
            "no bar painted — the clause would pass vacuously"
        )
        let capture = CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY,
            width: 400,
            height: 300
        )
        core.tiler.seedStash(Self.window, frame: capture)
        core.clampFloatsClearOfBars()
        let commanded = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the sweep never wrote a frame for a covered capture"
        )
        #expect(commanded.minY >= painted.maxY)
        #expect(commanded.size == capture.size)
        // The seed moves WITH the window, so the echo consumes it
        // rather than a later pass re-delivering the covered one.
        #expect(core.tiler.stashOriginal(Self.window) == commanded)
    }
}
