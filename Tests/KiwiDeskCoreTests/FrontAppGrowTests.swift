import AppKit
import Testing

@testable import KiwiDeskCore

/// The front-app segment joining or leaving a shown bar (#1903): it
/// grows out of the run's end on the plate glide and shrinks back
/// into it, stops being a target and cuts its glass at once, and
/// snaps where no glide plays. The first show after a hide lands.
@Suite("Front-app grow and shrink (#1903)", .serialized)
@MainActor
struct FrontAppGrowTests {
    init() { LiquidGlassGate.override = { false } }

    /// Space Bar with a front app standing for window 1 — a target
    /// the shrink must drop — or none.
    private func sync(
        _ manager: SpaceBarManager,
        front: WindowID?
    ) throws -> SpaceBarOverlay {
        let base = paintedSpaceBar(front: front, spaces: 2)
        let app = front.map { id in
            SpaceBarItemView.App(
                name: "Finder",
                icon: nil,
                glyph: nil,
                focused: true,
                count: 1,
                windows: [id]
            )
        }
        manager.sync([
            SpaceBarManager.Bar(
                display: base.display,
                items: base.items,
                frontApp: app,
                frontWindow: base.frontWindow,
                strip: base.strip,
                style: base.style,
                stateMarkColors: base.stateMarkColors
            )
        ])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    @Test("A leaving segment shrinks, untargeted at once")
    func leavingShrinks() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let manager = SpaceBarManager()
        let overlay = try sync(manager, front: WindowID(1))
        try #require(!overlay.frontName.isHidden)
        try #require(overlay.frontWindows == [WindowID(1)])
        _ = try sync(manager, front: nil)
        #expect(overlay.frontLeaving, "it glides shut")
        #expect(!overlay.frontName.isHidden, "drawn until it lands")
        #expect(overlay.frontWindows.isEmpty, "no longer a target")
        #expect(overlay.frontMenuHit == .empty)
    }

    @Test("A segment drawn again ends the shrink")
    func reshownEndsTheShrink() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let manager = SpaceBarManager()
        let overlay = try sync(manager, front: WindowID(1))
        _ = try sync(manager, front: nil)
        _ = try sync(manager, front: WindowID(1))
        #expect(!overlay.frontLeaving)
        #expect(overlay.frontWindows == [WindowID(1)])
    }

    @Test("Under Reduce Motion the segment snaps away")
    func reducedSnaps() throws {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let manager = SpaceBarManager()
        let overlay = try sync(manager, front: WindowID(1))
        _ = try sync(manager, front: nil)
        #expect(!overlay.frontLeaving)
        #expect(overlay.frontName.isHidden)
    }

    /// A joining segment lands where its render laid it, alpha
    /// full, whatever it stood at for the glide; under Reduce
    /// Motion the stand and the glide land in one turn.
    @Test("A joining segment lands where its render laid it")
    func joiningLands() throws {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let manager = SpaceBarManager()
        let overlay = try sync(manager, front: nil)
        _ = try sync(manager, front: WindowID(1))
        let joined = overlay.frontName.frame
        let fresh = try sync(SpaceBarManager(), front: WindowID(1))
        #expect(joined == fresh.frontName.frame)
        #expect(overlay.frontName.alphaValue == 1)
        #expect(joined.width > 0)
    }

    @Test("The collapse shuts a frame at the lead along the axis")
    func collapseGeometry() {
        let frame = CGRect(x: 40, y: 2, width: 60, height: 20)
        #expect(
            SpaceBarOverlay.collapsed(frame, at: 30, horizontal: true)
                == CGRect(x: 30, y: 2, width: 0, height: 20)
        )
        #expect(
            SpaceBarOverlay.collapsed(frame, at: 5, horizontal: false)
                == CGRect(x: 40, y: 5, width: 60, height: 0)
        )
    }
}
