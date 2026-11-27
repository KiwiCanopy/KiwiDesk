import Foundation
import Testing

@testable import KiwiDeskCore

/// A split stored as per-mille shares (#3647 ▸ lane 3) resolves to
/// points that tile any screen exactly, and crosses back without
/// moving an edge a write did not touch.
@Suite("Screen shares (#3647)")
struct ScreenSharesTests {
    /// Three side-by-side areas, the middle one stacked in two.
    private func nested(width: Int, height: Int) throws -> ScreenSplit {
        let halves = try #require(
            ScreenSplit.whole(width: width, height: height)
                .splitting(0, .sideBySide)
        )
        let thirds = try #require(halves.splitting(1, .sideBySide))
        return try #require(thirds.splitting(1, .stacked))
    }

    @Test("resolved shares tile every screen exactly")
    func resolvedTiles() throws {
        let shares = ScreenShares(
            try nested(width: 3440, height: 1440),
            width: 3440,
            height: 1440
        )
        #expect(shares.problem == nil)
        for (width, height) in [(3440, 1440), (1512, 982), (1001, 799)] {
            let split = shares.resolved(width: width, height: height)
            #expect(
                ScreenArea.problem(
                    with: split.areas,
                    width: width,
                    height: height,
                    minimumSide: 1
                ) == nil,
                "\(width)x\(height)"
            )
        }
    }

    @Test("a split crosses to shares and back on its own screen")
    func roundTrip() throws {
        let split = try nested(width: 3440, height: 1440)
        let back = ScreenShares(split, width: 3440, height: 1440)
            .resolved(width: 3440, height: 1440)
        #expect(back.nextID == split.nextID)
        for area in split.areas {
            let other = try #require(back.areas.first { $0.id == area.id })
            #expect(abs(other.x - area.x) <= 2)
            #expect(abs(other.w - area.w) <= 4)
        }
    }

    /// On a screen under 1000 points a share is finer than a point,
    /// so re-quantizing a resolved split could move an edge; a
    /// write keeps the edges it did not touch.
    @Test("a write keeps an untouched edge's share")
    func keepsUntouchedEdges() throws {
        let stored = ScreenShares(
            areas: [
                ScreenArea(id: 0, x: 0, y: 0, w: 1000, h: 400),
                ScreenArea(id: 1, x: 0, y: 400, w: 1000, h: 600),
            ]
        )
        var split = stored.resolved(width: 1000, height: 799)
        split.areas[1].name = "Right"
        let written = ScreenShares(
            split,
            width: 1000,
            height: 799,
            keeping: stored
        )
        #expect(written.areas.map(\.y) == stored.areas.map(\.y))
        #expect(written.areas[1].name == "Right")
        // The control: re-quantized afresh, the edge moves.
        let fresh = ScreenShares(split, width: 1000, height: 799)
        #expect(fresh.areas.map(\.y) != stored.areas.map(\.y))
    }

    @Test("a screen takes its number's split, twins the lower one's")
    func projection() throws {
        let order = ScreenOrder(["A:2000x1000", "B:1000x1000", "A:2000x1000"])
        let split = try #require(
            ScreenSplit.whole(width: 1000, height: 1000)
                .splitting(0, .sideBySide)
        )
        var shares: [String: ScreenShares] = [:]
        shares[number: 1] = ScreenShares(split, width: 1000, height: 1000)
        let splits = shares.splits(order: order)
        #expect(splits["A:2000x1000"]?.areas.map(\.w) == [1000, 1000])
        #expect(splits["B:1000x1000"] == nil)
        #expect(shares.store(nil, on: "C:1x1", order: order) == false)
    }

    @Test("a fingerprint-keyed split refuses to decode")
    func fingerprintKeyRefuses() throws {
        var settings = TilingSettings()
        settings.displayAreas[number: 1] = .whole(after: nil)
        let data = try JSONEncoder().encode(settings)
        #expect(
            (try? JSONDecoder().decode(TilingSettings.self, from: data))
                != nil
        )
        let text = try #require(String(data: data, encoding: .utf8))
        let bad = text.replacingOccurrences(
            of: "\"1\":",
            with: "\"Wide:3440x1440\":"
        )
        #expect(
            (try? JSONDecoder().decode(
                TilingSettings.self,
                from: Data(bad.utf8)
            )) == nil
        )
    }
}
