import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The proof of #930 ruling 6: after an in-place restart, boot
/// issues no frame that differs from where each window was left.
/// Process A arranges a desk — the shown Space in each layout,
/// resized, beside a hidden Space holding tiles and a float the
/// user floated by hand — and writes the in-place snapshot;
/// process B scans the same windows where A left them, in
/// scrambled AX order and with the hand float scanned as tiled,
/// then runs the boot tail. Every issued frame must equal its
/// window's left frame, and the pass must have issued the shown
/// windows (the re-issue a Space switch forces), so a boot that
/// issued nothing cannot pass for one that moved nothing.
@Suite("In-place restart issues no motion (#930)", .serialized)
@MainActor
struct InPlaceRestartNoMotionTests {
    private static func frame(_ i: Int) -> CGRect {
        CGRect(
            x: 60 + 70 * i,
            y: 80 + 50 * i,
            width: 520,
            height: 380
        )
    }

    private static var windows: [F.Window] {
        var list: [F.Window] = (1...4).map {
            .init(id: WindowID(UInt32($0)), space: F.shown, frame: frame($0))
        }
        list += [
            .init(id: WindowID(11), space: F.hidden, frame: frame(5)),
            .init(id: WindowID(12), space: F.hidden, frame: frame(6)),
            .init(id: WindowID(13), space: F.hidden, frame: frame(7)),
        ]
        return list
    }

    private static let shownIDs = (1...4).map { WindowID(UInt32($0)) }

    /// Process A's desk in `mode`, with that layout's session
    /// sizing moved off its defaults.
    private static func arrange(_ mode: LayoutMode) -> KiwiCore? {
        guard let core = F.processA(windows) else { return nil }
        // Floated by hand: a manual override the scan cannot see.
        core.state.setFloating(WindowID(13), true)
        core.setSpaceMode(F.shown, mode)
        core.state.workspaces.withSpace(F.shown) { space in
            switch mode {
            case .bsp:
                space.sessionRatios.splitRatioH = 0.31
                space.sessionRatios.splitRatioV = 0.58
            case .stack:
                space.sessionRatios.masterRatio = 0.62
                space.stackWeights = [WindowID(3): 1.7]
            case .track:
                space.trackBreaks = [WindowID(1), WindowID(3)]
                space.trackWeights = [WindowID(1): 1.4]
            case .scrolling:
                space.sessionRatios.slotSize = .fraction(0.63)
                space.focused = WindowID(3)
            case .monocle:
                space.focused = WindowID(2)
            default:
                break
            }
        }
        return core
    }

    private func proveNoMotion(_ mode: LayoutMode) throws {
        let a = try #require(Self.arrange(mode))
        let left = F.settle(a)
        let session = try F.crossed(a.sessionSnapshot(inPlace: true))
        var scanned = Self.windows
        scanned[6].floating = false
        let (b, issued) = try #require(
            F.processB(scanned, left: left, session: session)
        )
        let moved = Set(issued.map(\.0))
        for id in Self.shownIDs {
            #expect(moved.contains(id), "w\(id.raw) was never issued")
        }
        for (id, frame) in issued {
            #expect(
                frame == left[id],
                "\(mode): w\(id.raw) issued \(frame), left at \(left[id]!)"
            )
        }
        #expect(b.state.workspaces[F.shown]?.mode == mode)
        #expect(b.state.windows[WindowID(13)]?.isFloating == true)
    }

    @Test("bsp", .enabled(if: NSScreen.main != nil))
    func bsp() throws { try proveNoMotion(.bsp) }

    @Test("stack", .enabled(if: NSScreen.main != nil))
    func stack() throws { try proveNoMotion(.stack) }

    @Test("track", .enabled(if: NSScreen.main != nil))
    func track() throws { try proveNoMotion(.track) }

    @Test("Scrolling, panned", .enabled(if: NSScreen.main != nil))
    func scrolling() throws {
        // Panned for real: the focus sits past the first slot, so
        // the viewport rests away from its home.
        let a = try #require(Self.arrange(.scrolling))
        _ = F.settle(a)
        let rest = a.state.workspaces[F.shown]?.scrollRest
        #expect((rest?.offset ?? 0) != 0)
        try proveNoMotion(.scrolling)
    }

    @Test("Monocle", .enabled(if: NSScreen.main != nil))
    func monocle() throws { try proveNoMotion(.monocle) }

    /// Monocle with a float holding the focus: the member shown is
    /// the one the engine held (#881), not the focus, so the
    /// carried hold decides a frame.
    @Test(
        "Monocle under a float focus",
        .enabled(if: NSScreen.main != nil)
    )
    func monocleUnderAFloatFocus() throws {
        let float = WindowID(5)
        var windows = Self.windows
        windows.append(
            .init(id: float, space: F.shown, frame: Self.frame(8))
        )
        let park: (KiwiCore) -> Void = {
            $0.tiler.settings.monocle.hideStyle = .park
        }
        let a = try #require(F.processA(windows, configure: park))
        a.state.setFloating(float, true)
        a.state.setFloating(WindowID(13), true)
        a.setSpaceMode(F.shown, .monocle)
        a.state.workspaces.focus(WindowID(3), in: F.shown)
        _ = F.settle(a)
        a.state.workspaces.focus(float, in: F.shown)
        let left = F.settle(a)
        #expect(a.tiler.monocleShownMembers[F.shown] == WindowID(3))
        let session = try F.crossed(a.sessionSnapshot(inPlace: true))
        // Both hand floats are scanned as the tiles they look like.
        let scanned = windows.map { window -> F.Window in
            var found = window
            found.floating = false
            return found
        }
        let (b, issued) = try #require(
            F.processB(
                scanned,
                left: left,
                session: session,
                configure: park
            )
        )
        #expect(!issued.isEmpty)
        for (id, frame) in issued {
            #expect(
                frame == left[id],
                "w\(id.raw) issued \(frame), left at \(left[id]!)"
            )
        }
        #expect(b.tiler.monocleShownMembers[F.shown] == WindowID(3))
    }

    @Test("a floating Space", .enabled(if: NSScreen.main != nil))
    func floating() throws { try proveNoMotion(.floating) }

    /// A held Space (#1646): process B has no such Space until the
    /// boot door re-creates it, so without it the held windows
    /// would join the Space in front and tile on screen.
    @Test("a held Space", .enabled(if: NSScreen.main != nil))
    func heldSpace() throws {
        let held = SpaceID("7")
        let origin = HeldOrigin(
            name: SpaceID("3"),
            screen: "DELL:2560x1440",
            icon: nil,
            arrangement: nil
        )
        var windows = Self.windows
        windows += [
            .init(id: WindowID(21), space: held, frame: Self.frame(8)),
            .init(id: WindowID(22), space: held, frame: Self.frame(9)),
        ]
        let a = try #require(
            F.processA(windows) { core in
                core.state.workspaces.ensureSpace(held)
                core.state.heldSpaces[held] = origin
                core.resolveSpaceDisplays()
            }
        )
        let left = F.settle(a)
        let session = try F.crossed(a.sessionSnapshot(inPlace: true))
        let (b, issued) = try #require(
            F.processB(windows, left: left, session: session)
        )
        let moved = Set(issued.map(\.0))
        for id in Self.shownIDs {
            #expect(moved.contains(id), "w\(id.raw) was never issued")
        }
        for (id, frame) in issued {
            #expect(
                frame == left[id],
                "w\(id.raw) issued \(frame), left at \(left[id]!)"
            )
        }
        #expect(b.state.heldSpaces[held] == origin)
        #expect(
            b.state.workspaces[held]?.windows
                == [WindowID(21), WindowID(22)]
        )
        #expect(b.state.workspaces[F.shown]?.windows == Self.shownIDs)
    }

    /// The negative control: the same boot from a PLAIN snapshot
    /// — what a quit writes — moves the resized layouts, so the
    /// in-place payload is what holds them.
    @Test(
        "a plain snapshot moves a resized layout",
        .enabled(if: NSScreen.main != nil)
    )
    func plainSnapshotMoves() throws {
        for mode in [LayoutMode.bsp, .scrolling] {
            let a = try #require(Self.arrange(mode))
            let left = F.settle(a)
            let session = try F.crossed(a.sessionSnapshot())
            let (_, issued) = try #require(
                F.processB(Self.windows, left: left, session: session)
            )
            #expect(
                issued.contains { $0.1 != left[$0.0] },
                "\(mode): a plain boot moved nothing"
            )
        }
    }
}
