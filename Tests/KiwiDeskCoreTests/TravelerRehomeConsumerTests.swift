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

    /// The moved frame is clamped clear of the strips painted on
    /// the RENDER screen: the home-keyed clamp never sees a
    /// traveler, so without this arm it lands under the target's
    /// bar (#242).
    @Test(
        "the moved frame clears the render screen's bar",
        .enabled(if: NSScreen.main != nil)
    )
    func movedFrameClearsTheBar() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        f.core.tiler.settings.spaceBarStyle.enabled = true
        f.core.tiler.settings.spaceBarStyle.edge = .top
        f.core.tiler.settings.spaceBarStyle.thickness = 40
        f.core.updateSpaceBar()
        let strip = try #require(
            f.core.spaceBars.shownStrips.first?.1,
            "no bar painted — the clause would pass vacuously"
        )
        // Sit at the very top of the other screen so the naive
        // proportional target lands under the strip.
        let top = CGRect(
            x: f.other.minX + 100,
            y: f.other.minY,
            width: 400,
            height: 300
        )
        f.core.state.apply(.windowMoved(Self.traveler, top))
        f.core.retile(animated: false, force: true)
        let commanded = try #require(
            f.core.tiler.recentInstantTarget(Self.traveler)
        )
        #expect(commanded.minY >= strip.maxY)
    }

    /// The SIZE half (#1091): a traveler taller than the region
    /// between the render screen's bars is fitted into it, or the
    /// position clamp pushes it past the opposite edge.
    @Test(
        "an oversized traveler is fitted into the render region",
        .enabled(if: NSScreen.main != nil)
    )
    func oversizedTravelerIsFitted() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        f.core.tiler.settings.spaceBarStyle.enabled = true
        f.core.tiler.settings.spaceBarStyle.edge = .top
        f.core.tiler.settings.spaceBarStyle.thickness = 40
        f.core.tiler.settings.floatScaleOnDisplayChange = false
        f.core.updateSpaceBar()
        _ = try #require(f.core.spaceBars.shownStrips.first?.1)
        let region = try #require(f.core.floatBounds(on: SpaceID("2")))
        let tall = CGRect(
            x: f.other.minX,
            y: f.other.minY,
            width: f.other.width,
            height: f.other.height + 400
        )
        f.core.state.apply(.windowMoved(Self.traveler, tall))
        f.core.retile(animated: false, force: true)
        let commanded = try #require(
            f.core.tiler.recentInstantTarget(Self.traveler)
        )
        // The SIZE is bounded by the region; the position is
        // only pushed clear of the bar (by the ring inset), the
        // way the home-keyed net leaves position to the user.
        #expect(commanded.height <= region.height)
        #expect(commanded.minY >= region.minY)
    }

    /// With the relayout animation on, a retile mid-flight reads
    /// the commanded frame, never the in-flight echo — or each
    /// pass re-scales the traveler from wherever it currently is.
    @Test(
        "a retile mid-animation moves nothing twice",
        .enabled(if: NSScreen.main != nil)
    )
    func midAnimationRetileIsIdempotent() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        f.core.tiler.settings.animations.onRelayout = true
        f.core.retile(animated: true, force: true)
        let first = try #require(
            f.core.tiler.animation.commandedFrame(
                window: Self.traveler,
                includingHeldGlide: false
            )
        )
        #expect(first == expected(f))
        // An in-flight echo one tenth of the way: still mostly on
        // the SOURCE screen, so an echo-fed base would compute a
        // second, smaller target.
        let early = CGRect(
            x: f.frame.minX + (first.minX - f.frame.minX) / 10,
            y: f.frame.minY + (first.minY - f.frame.minY) / 10,
            width: f.frame.width + (first.width - f.frame.width) / 10,
            height: f.frame.height
                + (first.height - f.frame.height) / 10
        )
        f.core.state.apply(.windowMoved(Self.traveler, early))
        f.core.retile(animated: true, force: true)
        #expect(
            f.core.tiler.animation.commandedFrame(
                window: Self.traveler,
                includingHeldGlide: false
            ) == first
        )
    }

    /// A MEMBER of the floating space parked on another screen
    /// is the user's (or `reanchorFloat`'s on a move), never the
    /// net's — the net moves travelers only.
    @Test(
        "a member parked on another screen is not the net's",
        .enabled(if: NSScreen.main != nil)
    )
    func memberOnAnotherScreenIsLeftAlone() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let member = WindowID(2)
        f.core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: member,
                    pid: 2,
                    appName: "Member",
                    frame: f.frame
                )
            )
        )
        f.core.state.workspaces.add(member, to: SpaceID("2"))
        f.core.retile(animated: false, force: true)
        #expect(f.core.tiler.recentInstantTarget(member) == nil)
        #expect(f.core.tiler.recentInstantTarget(Self.traveler) != nil)
    }

    /// The net rides the retile's own `animated`, not the
    /// relayout setting: a switch retiles instantly and its
    /// traveler must not spring while every sibling snaps.
    @Test(
        "the net snaps when the retile snaps",
        .enabled(if: NSScreen.main != nil)
    )
    func netFollowsTheRetilesAnimated() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        f.core.tiler.settings.animations.onRelayout = true
        f.core.retile(animated: false, force: true)
        #expect(f.core.tiler.recentInstantTarget(Self.traveler) != nil)
    }

    /// A second retile before the echo lands re-issues nothing:
    /// the commanded base already sits on the destination.
    @Test(
        "a retile before the echo re-homes nothing twice",
        .enabled(if: NSScreen.main != nil)
    )
    func retileBeforeTheEchoIsIdempotent() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        var lines: [String] = []
        f.core.onLog = { lines.append($0) }
        f.core.retile(animated: false, force: true)
        f.core.retile(animated: false, force: true)
        #expect(
            lines.filter { $0.contains("traveler re-home") }.count == 1
        )
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
