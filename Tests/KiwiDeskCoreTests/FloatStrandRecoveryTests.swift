import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = FloatStrandFixture

/// A corner is never an original (#1352). macOS lifts a parked
/// window off the line it was asked for — measured 4 pt and
/// 18 pt on the device — and a 2 pt corner test read every
/// lifted park as a user move, which consumed the capture and
/// let the next stash capture the corner itself.
@Suite("Stash corner recognition (#1352)")
@MainActor
struct StashCornerLiftTests {
    @Test(
        "The exact park frame looks stashed at either corner",
        arguments: [
            TilingEngine.HideCorner.bottomLeft, .bottomRight,
        ]
    )
    func exactCorner(corner: TilingEngine.HideCorner) {
        #expect(
            TilingEngine.looksStashed(F.parked(corner), in: F.bounds)
        )
    }

    @Test(
        "A park the OS lifted still looks stashed",
        arguments: [CGFloat(4), 18]
    )
    func liftedPark(lift: CGFloat) {
        #expect(
            TilingEngine.looksStashed(
                F.parked(lift: lift),
                in: F.bounds
            )
        )
    }

    @Test("A lift past the visibility floor is not a park")
    func liftBeyondFloor() {
        let lift = WindowServerFacts.visibilityFloor + 1
        #expect(
            !TilingEngine.looksStashed(
                F.parked(lift: lift),
                in: F.bounds
            )
        )
    }

    @Test("A frame off the corner's x is not a park, however low")
    func offCornerX() {
        var frame = F.parked()
        frame.origin.x -= 10
        #expect(!TilingEngine.looksStashed(frame, in: F.bounds))
    }

    @Test("A stash refuses to capture a corner as the original")
    func stashRefusesCornerCapture() {
        let engine = TilingEngine()
        let window = ManagedWindow(
            id: WindowID(1),
            pid: 1,
            appName: "A",
            frame: F.parked(lift: 4),
            isFloating: true
        )
        engine.stash(
            window,
            in: F.bounds,
            corner: .bottomRight,
            force: true,
            capturesOriginal: true
        )
        #expect(engine.stashOriginal(WindowID(1)) == nil)
    }

    @Test("Centring shrinks an oversized frame to the region")
    func centredShrinks() {
        let region = CGRect(x: 10, y: 20, width: 500, height: 400)
        let frame = FloatRecovery.centred(
            CGSize(width: 900, height: 300),
            in: region
        )
        #expect(frame.width == 500)
        #expect(frame.height == 300)
        #expect(frame.midX == region.midX)
        #expect(frame.midY == region.midY)
    }
}

/// The retile-time net (#1352): an effective float on a shown
/// space with no capture and a frame at the corner is seeded a
/// centred capture for the restore pass to deliver. The DECISION
/// is read through `recoverStrandedFloats()` directly; the
/// clauses that go through `retile()` pin the wiring and rely on
/// the host's real screens intersecting `bounds` (the restore
/// pass's display-gone read is unpinned).
@Suite("Stranded float recovery (#1352)", .serialized)
@MainActor
struct FloatStrandRecoveryTests {
    @Test(
        "A floating-mode member at the corner is re-centred",
        .enabled(if: NSScreen.main != nil)
    )
    func recentresFloatingModeMember() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked(lift: 4))
        )
        core.retile()
        #expect(core.tiler.stashOriginal(F.window) == F.centred)
    }

    @Test(
        "A float-flagged window on a tiled space is re-centred",
        .enabled(if: NSScreen.main != nil)
    )
    func recentresFlaggedFloat() throws {
        let core = try #require(
            F.makeCore(mode: .bsp, frame: F.parked(), floating: true)
        )
        core.recoverStrandedFloats()
        #expect(core.tiler.stashOriginal(F.window) == F.centred)
    }

    @Test(
        "A tiled window at the corner is the layout's to place",
        .enabled(if: NSScreen.main != nil)
    )
    func leavesTiledWindowToTheLayout() throws {
        let core = try #require(
            F.makeCore(mode: .bsp, frame: F.parked())
        )
        core.recoverStrandedFloats()
        #expect(core.tiler.stashOriginal(F.window) == nil)
    }

    @Test(
        "A pending capture is delivered, not replaced",
        .enabled(if: NSScreen.main != nil)
    )
    func keepsPendingCapture() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked())
        )
        let original = F.original
        core.tiler.seedStash(F.window, frame: original)
        core.recoverStrandedFloats()
        #expect(core.tiler.stashOriginal(F.window) == original)
    }

    @Test(
        "A float away from the corner is left where it is",
        .enabled(if: NSScreen.main != nil)
    )
    func leavesPlacedFloatAlone() throws {
        let core = try #require(
            F.makeCore(
                mode: .floating,
                frame: CGRect(
                    x: 100,
                    y: 100,
                    width: 800,
                    height: 600
                )
            )
        )
        core.recoverStrandedFloats()
        #expect(core.tiler.stashOriginal(F.window) == nil)
    }

    @Test(
        "The session snapshot carries a parked float's capture",
        .enabled(if: NSScreen.main != nil)
    )
    func snapshotCarriesTheCapture() throws {
        let core = try #require(
            F.makeCore(mode: .floating, frame: F.parked())
        )
        let original = F.original
        core.tiler.seedStash(F.window, frame: original)
        let record = core.sessionSnapshot().windows.first {
            $0.windowID == F.window
        }
        #expect(record?.frame == original)
        // The state itself still holds the corner: the
        // substitution is the snapshot's, not a state write.
        #expect(
            core.state.windows[F.window]?.frame == F.parked()
        )
    }
}
