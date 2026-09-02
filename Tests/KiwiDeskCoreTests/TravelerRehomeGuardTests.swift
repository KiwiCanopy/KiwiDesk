import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The traveler re-home's guards (#1217), through the real retile:
/// what the net must NOT do — move a member, spring when the retile
/// snaps, re-home twice before the echo, seed a size bound. Split
/// from `TravelerRehomeConsumerTests` at the tests.md file ceiling
/// with a per-file fixture copy (the #878 shape: one real screen,
/// a second fabricated through `allScreenBounds`).
@Suite("Traveler re-home guards (#1217)", .serialized)
@MainActor
struct TravelerRehomeGuardTests {
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
        // A LARGER second screen, so a proportional move changes
        // the size — a same-size twin would echo the pre-ask size,
        // which the size-bound learner bars as "not redrawn".
        let other = CGRect(
            x: home.maxX + 100,
            y: home.minY,
            width: home.width * 1.5,
            height: home.height * 1.5
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

    /// The re-home is a size change outside the layout's asks
    /// (#677): the app's echo of it must not read as a refusal of
    /// the previous tiled space's ask, or the next tiled space
    /// places the traveler as a residue for a beat (device,
    /// 2026-09-02).
    @Test(
        "the re-home's echo seeds no size bound",
        .enabled(if: NSScreen.main != nil)
    )
    func rehomeEchoSeedsNoSizeBound() throws {
        let f = try #require(makeFixture(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // A fake window gets no "recent set" stamp (no AX element
        // to set), so every echo below would read as a genuine
        // resize; the seam makes them the engine's own echoes.
        f.core.tiler.echoGraceOverride = { _ in true }
        // The previous tiled space asks the traveler for a frame.
        f.core.state.workspaces.activate(SpaceID("1"))
        f.core.retile(animated: false, force: true)
        // The app echoes that frame (clearing the instant
        // target), then the user drags it onto the other screen.
        f.core.handle(.windowResized(Self.traveler, f.frame))
        f.core.state.workspaces.activate(SpaceID("2"))
        f.core.state.apply(.windowMoved(Self.traveler, f.frame))
        f.core.retile(animated: false, force: true)
        let commanded = try #require(
            f.core.tiler.recentInstantTarget(Self.traveler)
        )
        // The app echoes the re-homed frame.
        f.core.handle(.windowResized(Self.traveler, commanded))
        #expect(
            f.core.tiler.candidateSizeBound(for: Self.traveler) == nil
        )
    }

}
