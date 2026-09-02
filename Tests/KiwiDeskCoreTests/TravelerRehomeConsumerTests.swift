import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The traveler re-home through the real retile (#1217): a ∞
/// window rendering on a floating-mode space of ANOTHER display
/// is moved onto that display; on the same display, on a tiled
/// target, or mid-drag it is left to the rules that already own
/// it. One real screen, with a second fabricated through the
/// `allScreenBounds` seam and the traveler's frame placed on it —
/// the #878 fixture shape.
///
/// `TravelerRehomeTests` holds the decision's algebra; this suite
/// is the consumer, which that one structurally cannot see.
@Suite("Traveler re-home through the retile (#1217)", .serialized)
@MainActor
struct TravelerRehomeConsumerTests {
    private static let traveler = WindowID(1)

    private struct Fixture {
        let core: KiwiCore
        let home: CGRect
        let other: CGRect
        let frame: CGRect
    }

    /// A ∞ window homed in a tiled space, its frame on the OTHER
    /// screen, with a second space on the same display active in
    /// `mode`.
    private func makeFixture(mode: LayoutMode) -> Fixture? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let home = GeometryUtils.axVisibleFrame(of: screen)
        let other = CGRect(
            x: home.maxX + 100,
            y: home.minY,
            width: home.width,
            height: home.height
        )
        let frame = CGRect(
            x: other.minX + 100,
            y: other.minY + 100,
            width: 400,
            height: 300
        )
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in home }
        core.tiler.allScreenBounds = { [home, other] }
        core.tiler.settings.animations.onRelayout = false
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.traveler,
                    pid: 1,
                    appName: "Sticky",
                    frame: frame,
                    stickyScope: .global
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let second = SpaceID("2")
        core.state.workspaces.ensureSpace(second)
        core.state.workspaces.assign(second, to: display.id)
        core.state.workspaces.setMode(second, mode)
        core.state.workspaces.activate(second)
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        return Fixture(core: core, home: home, other: other, frame: frame)
    }

    private func expected(_ f: Fixture) -> CGRect {
        FloatReanchor.target(
            frame: f.frame,
            from: f.other,
            to: f.home,
            scaleSize: f.core.tiler.settings.floatScaleOnDisplayChange
        )
    }

    @Test(
        "a traveler on a floating space of another display is moved",
        .enabled(if: NSScreen.main != nil)
    )
    func movedOntoTheFloatingSpacesScreen() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        f.core.retile(animated: false, force: true)
        let commanded = try #require(
            f.core.tiler.recentInstantTarget(Self.traveler),
            "the retile never wrote a frame — the traveler stayed"
        )
        #expect(commanded == expected(f))
        #expect(f.home.contains(commanded))
    }

    @Test(
        "a traveler already on the floating space's screen stays",
        .enabled(if: NSScreen.main != nil)
    )
    func sameScreenStays() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let here = CGRect(
            x: f.home.minX + 50,
            y: f.home.minY + 50,
            width: 400,
            height: 300
        )
        f.core.state.apply(.windowMoved(Self.traveler, here))
        f.core.retile(animated: false, force: true)
        #expect(f.core.tiler.recentInstantTarget(Self.traveler) == nil)
    }

    @Test(
        "a tiled target keeps the layout's placement",
        .enabled(if: NSScreen.main != nil)
    )
    func tiledTargetKeepsTheLayout() throws {
        let f = try #require(makeFixture(mode: .bsp))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        f.core.retile(animated: false, force: true)
        let commanded = try #require(
            f.core.tiler.recentInstantTarget(Self.traveler)
        )
        #expect(commanded != expected(f))
        #expect(f.home.contains(commanded))
    }

    @Test(
        "a traveler mid-drag is left to the pointer",
        .enabled(if: NSScreen.main != nil)
    )
    func dragExemptIsLeftAlone() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        f.core.tiler.dragExemptWindow = Self.traveler
        f.core.retile(animated: false, force: true)
        #expect(f.core.tiler.recentInstantTarget(Self.traveler) == nil)
    }
}
