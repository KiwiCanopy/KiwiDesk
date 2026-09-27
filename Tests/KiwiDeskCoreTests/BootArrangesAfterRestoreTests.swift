import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// Boot restores before it arranges (#930 ruling 4): the scan
/// files every window in the active Space in AX order, so a
/// retile ahead of the session replay tiled the hidden Space's
/// windows on screen and parked them again. Driven through
/// `arrangeBootDesk`, the tail `finishBoot` runs.
@Suite("Boot restores before it arranges (#930)", .serialized)
@MainActor
struct BootArrangesAfterRestoreTests {
    private static let windows: [F.Window] = [
        .init(
            id: WindowID(1),
            space: F.shown,
            frame: CGRect(x: 40, y: 60, width: 700, height: 500)
        ),
        .init(
            id: WindowID(2),
            space: F.shown,
            frame: CGRect(x: 90, y: 90, width: 700, height: 500)
        ),
        .init(
            id: WindowID(11),
            space: F.hidden,
            frame: CGRect(x: 120, y: 140, width: 640, height: 480)
        ),
        .init(
            id: WindowID(12),
            space: F.hidden,
            frame: CGRect(x: 160, y: 180, width: 640, height: 480)
        ),
        .init(
            id: WindowID(13),
            space: F.hidden,
            frame: CGRect(x: 300, y: 260, width: 500, height: 400),
            floating: true
        ),
    ]

    private static var hiddenIDs: Set<WindowID> {
        Set(windows.filter { $0.space == F.hidden }.map(\.id))
    }

    @Test(
        "A hidden Space's windows are never tiled on screen",
        .enabled(if: NSScreen.main != nil)
    )
    func hiddenWindowsStayParked() throws {
        let a = try #require(F.processA(Self.windows))
        let left = F.settle(a)
        let session = try F.crossed(a.sessionSnapshot())
        let (b, issued) = try #require(
            F.processB(Self.windows, left: left, session: session)
        )
        // Non-vacuous: the boot pass re-issued the shown tiles.
        #expect(issued.contains { $0.0 == WindowID(1) })
        for (id, frame) in issued where Self.hiddenIDs.contains(id) {
            #expect(
                frame == left[id],
                "w\(id.raw) was issued \(frame), left at \(left[id]!)"
            )
        }
        for id in Self.hiddenIDs {
            #expect(b.state.workspaces.space(of: id) == F.hidden)
        }
    }

    @Test(
        "A parked float keeps the capture the snapshot carried",
        .enabled(if: NSScreen.main != nil)
    )
    func parkedFloatKeepsItsCapture() throws {
        let a = try #require(F.processA(Self.windows))
        let left = F.settle(a)
        let float = WindowID(13)
        let capture = try #require(a.tiler.stashOriginal(float))
        let session = try F.crossed(a.sessionSnapshot())
        let (b, _) = try #require(
            F.processB(Self.windows, left: left, session: session)
        )
        // Not `recoverStrandedFloats`' centred seed, which a
        // retile over the scan's filing would have planted.
        #expect(b.tiler.stashOriginal(float) == capture)
    }

    @Test(
        "No session: the scan's order is the arrangement",
        .enabled(if: NSScreen.main != nil)
    )
    func noSessionRetilesOnce() throws {
        let core = try #require(F.makeCore())
        core.state.apply(.windowCreated(F.managed(Self.windows[0])))
        let issued = F.record(core) {
            core.arrangeBootDesk(session: nil)
        }
        #expect(issued.contains { $0.0 == WindowID(1) })
    }
}
