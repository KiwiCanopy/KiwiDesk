import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private func ids(_ raw: [UInt32]) -> [WindowID] {
    raw.map { WindowID($0) }
}

/// A sticky window gets no exemption in a scrolled run (#2235,
/// owner 2026-10-22; Grid #2541), and a cascade raises in frame
/// order (#414 v2).
@Suite("Run sticky and cascade order")
struct RunStickyTests {
    @MainActor
    @Test("A sticky scrolls in a track like any window")
    func trackColumnExemption() {
        // One track (no breaks), four windows in a column that
        // shows three: sticky 4 waits parked like any other.
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 600, height: 900),
            gaps: Gaps.uniform(0),
            minWindowSize: 300,
            sticky: [WindowID(4)]
        )
        let frames = TrackLayout().calculateGeometry(
            for: ids([1, 2, 3, 4]),
            in: context
        )
        guard let stickyFrame = frames[WindowID(4)] else {
            Issue.record("Expected a frame for the sticky")
            return
        }
        #expect(
            TilingEngine.looksStashed(stickyFrame, in: context.bounds)
        )
        #expect(frames[WindowID(1)] != frames[WindowID(2)])
    }

    @MainActor
    @Test("A sticky scrolls in a stack zone like any window")
    func stackZoneExemption() {
        // One master + a stack zone showing two of three: sticky
        // 4 (last in the zone) waits parked like any other.
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 700),
            gaps: Gaps.uniform(0),
            minWindowSize: 300,
            sticky: [WindowID(4)]
        )
        let frames = StackLayout().calculateGeometry(
            for: ids([1, 2, 3, 4]),
            in: context
        )
        guard let stickyFrame = frames[WindowID(4)] else {
            Issue.record("Expected a frame for the sticky")
            return
        }
        #expect(
            TilingEngine.looksStashed(stickyFrame, in: context.bounds)
        )
        #expect(frames[WindowID(2)] != frames[WindowID(3)])
    }

    @MainActor
    @Test("A sticky scrolls in a grid's last track like any window")
    func gridRunExemption() {
        // Rigid 2 × 2, six windows: the last row shows 3 and 4;
        // sticky 6 waits parked like any other (#2541).
        var params = GridParams()
        params.type = .rigid
        params.columns = 2
        params.rows = 2
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1600, height: 1200),
            gaps: Gaps.uniform(0),
            minWindowSize: 100,
            sticky: [WindowID(6)],
            grid: params
        )
        let frames = GridLayout().calculateGeometry(
            for: ids([1, 2, 3, 4, 5, 6]),
            in: context
        )
        guard let stickyFrame = frames[WindowID(6)] else {
            Issue.record("Expected a frame for the sticky")
            return
        }
        #expect(
            TilingEngine.looksStashed(stickyFrame, in: context.bounds)
        )
        #expect(
            !TilingEngine.looksStashed(
                frames[WindowID(3)] ?? .null,
                in: context.bounds
            )
        )
    }

    @Test("cascadeRaiseOrder raises top frames first")
    func cascadeRaiseOrderFollowsFrames() {
        // Frame order (minY) disagrees with array order: the
        // topmost frame raises FIRST even though it sits last in
        // the array, so each lower one lands on top of it.
        let frames: [WindowID: CGRect] = [
            WindowID(10): CGRect(x: 0, y: 100, width: 50, height: 50),
            WindowID(20): CGRect(x: 0, y: 0, width: 50, height: 50),
            WindowID(30): CGRect(x: 0, y: 50, width: 50, height: 50),
        ]
        #expect(
            KiwiCore.cascadeRaiseOrder(
                ids([10, 20, 30]),
                frames: frames
            ) == ids([20, 30, 10])
        )
        // Ties (and missing frames) keep the input order.
        #expect(
            KiwiCore.cascadeRaiseOrder(
                ids([3, 1, 2]),
                frames: [:]
            ) == ids([3, 1, 2])
        )
    }
}
