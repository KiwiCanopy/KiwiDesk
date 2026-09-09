import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Pinned display (#531): every corner below is derived from it.
private let bounds = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)

private let size = CGSize(width: 800, height: 600)

private func parked(
    _ corner: TilingEngine.HideCorner = .bottomRight,
    lift: CGFloat = 0
) -> CGRect {
    var frame = TilingEngine.stashFrame(
        CGRect(origin: .zero, size: size),
        in: bounds,
        corner: corner
    )
    frame.origin.y -= lift
    return frame
}

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
            TilingEngine.looksStashed(parked(corner), in: bounds)
        )
    }

    @Test(
        "A park the OS lifted still looks stashed",
        arguments: [CGFloat(4), 18]
    )
    func liftedPark(lift: CGFloat) {
        #expect(
            TilingEngine.looksStashed(
                parked(lift: lift),
                in: bounds
            )
        )
    }

    @Test("A lift past the visibility floor is not a park")
    func liftBeyondFloor() {
        let lift = WindowServerFacts.visibilityFloor + 1
        #expect(
            !TilingEngine.looksStashed(
                parked(lift: lift),
                in: bounds
            )
        )
    }

    @Test("A frame off the corner's x is not a park, however low")
    func offCornerX() {
        var frame = parked()
        frame.origin.x -= 10
        #expect(!TilingEngine.looksStashed(frame, in: bounds))
    }

    @Test("A stash refuses to capture a corner as the original")
    func stashRefusesCornerCapture() {
        let engine = TilingEngine()
        let window = ManagedWindow(
            id: WindowID(1),
            pid: 1,
            appName: "A",
            frame: parked(lift: 4),
            isFloating: true
        )
        engine.stash(
            window,
            in: bounds,
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
/// centred capture for the restore pass to deliver.
@Suite("Stranded float recovery (#1352)", .serialized)
@MainActor
struct FloatStrandRecoveryTests {
    private static let window = WindowID(1)

    /// A core whose one shown space is `mode`, pinned to
    /// `bounds` on both display seams (#531), holding one
    /// window at `frame`. Nil where the host has no screen.
    private func makeCore(
        mode: LayoutMode,
        frame: CGRect,
        floating: Bool = false
    ) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in bounds }
        core.tiler.allScreenBounds = { [bounds] }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: floating
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, mode)
        return core
    }

    private var centred: CGRect {
        FloatRecovery.centred(size, in: bounds)
    }

    @Test(
        "A floating-mode member at the corner is re-centred",
        .enabled(if: NSScreen.main != nil)
    )
    func recentresFloatingModeMember() throws {
        let core = try #require(
            makeCore(mode: .floating, frame: parked(lift: 4))
        )
        core.retile()
        #expect(core.tiler.stashOriginal(Self.window) == centred)
    }

    @Test(
        "A float-flagged window on a tiled space is re-centred",
        .enabled(if: NSScreen.main != nil)
    )
    func recentresFlaggedFloat() throws {
        let core = try #require(
            makeCore(mode: .bsp, frame: parked(), floating: true)
        )
        core.retile()
        #expect(core.tiler.stashOriginal(Self.window) == centred)
    }

    @Test(
        "A tiled window at the corner is the layout's to place",
        .enabled(if: NSScreen.main != nil)
    )
    func leavesTiledWindowToTheLayout() throws {
        let core = try #require(
            makeCore(mode: .bsp, frame: parked())
        )
        core.retile()
        #expect(core.tiler.stashOriginal(Self.window) == nil)
    }

    @Test(
        "A pending capture is delivered, not replaced",
        .enabled(if: NSScreen.main != nil)
    )
    func keepsPendingCapture() throws {
        let core = try #require(
            makeCore(mode: .floating, frame: parked())
        )
        let original = CGRect(
            x: 300,
            y: 200,
            width: 800,
            height: 600
        )
        core.tiler.seedStash(Self.window, frame: original)
        core.retile()
        #expect(core.tiler.stashOriginal(Self.window) == original)
    }

    @Test(
        "A float away from the corner is left where it is",
        .enabled(if: NSScreen.main != nil)
    )
    func leavesPlacedFloatAlone() throws {
        let core = try #require(
            makeCore(
                mode: .floating,
                frame: CGRect(
                    x: 100,
                    y: 100,
                    width: 800,
                    height: 600
                )
            )
        )
        core.retile()
        #expect(core.tiler.stashOriginal(Self.window) == nil)
    }

    @Test(
        "The session snapshot carries a parked float's capture",
        .enabled(if: NSScreen.main != nil)
    )
    func snapshotCarriesTheCapture() throws {
        let core = try #require(
            makeCore(mode: .floating, frame: parked())
        )
        let original = CGRect(
            x: 300,
            y: 200,
            width: 800,
            height: 600
        )
        core.tiler.seedStash(Self.window, frame: original)
        let record = core.sessionSnapshot().windows.first {
            $0.windowID == Self.window
        }
        #expect(record?.frame == original)
        // The state itself still holds the corner: the
        // substitution is the snapshot's, not a state write.
        #expect(
            core.state.windows[Self.window]?.frame == parked()
        )
    }
}
