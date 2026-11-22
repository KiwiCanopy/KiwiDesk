import Foundation
import Testing

@testable import KiwiDeskCore

/// A split's cuts and its edits (#3517 rulings 20–23): ids kept on
/// the left or top, never minted twice, area 0 surviving a merge.
@Suite("Screen split edits")
struct ScreenSplitEditTests {
    private let whole = ScreenSplit.whole(width: 3440, height: 1440)

    @Test func cutsOfThreeSideBySide() throws {
        let split = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        let cuts = try #require(
            ScreenAreaCuts.cuts(of: split.areas, width: 3440, height: 1440)
        )
        #expect(cuts.map(\.position) == [1720, 2580])
        #expect(cuts.allSatisfy { $0.axis == .sideBySide })
        #expect(cuts[0].leading == [0])
        #expect(cuts[0].trailing == [1])
        #expect(cuts[1].leading == [1])
        #expect(cuts[1].trailing == [2])
        #expect(cuts.allSatisfy { $0.start == 0 && $0.end == 1440 })
    }

    @Test func splitKeepsTheIdOnTheLeadingHalf() throws {
        let odd = ScreenSplit.whole(width: 1001, height: 900)
        let split = try #require(odd.splitting(0, .sideBySide))
        #expect(split.areas.map(\.id) == [0, 1])
        #expect(split.areas.map(\.w) == [501, 500])
        #expect(split.areas[1].x == 501)
        #expect(split.nextID == 2)
        let stacked = try #require(odd.splitting(0, .stacked))
        #expect(stacked.areas.map(\.h) == [450, 450])
        #expect(stacked.areas[1].y == 450)
    }

    @Test func splitRefusesUnderTheFloor() {
        #expect(whole.splitting(0, .sideBySide, floor: 1800) == nil)
        #expect(whole.splitting(9, .sideBySide) == nil)
    }

    @Test func mergeKeepsAreaZero() throws {
        let split = try #require(whole.splitting(0, .sideBySide))
        let merged = try #require(split.merging(1, 0))
        #expect(merged.survivor == 0)
        #expect(merged.vanished == 1)
        #expect(merged.split.areas.map(\.w) == [3440])
        #expect(merged.split.isWhole)
    }

    @Test func mergeKeepsTheLeftOneOtherwise() throws {
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        let merged = try #require(three.merging(2, 1))
        #expect(merged.survivor == 1)
        #expect(merged.vanished == 2)
        #expect(merged.split.areas.map(\.id) == [0, 1])
        #expect(merged.split.areas.map(\.w) == [1720, 1720])
    }

    @Test func mergeRefusesNonNeighbours() throws {
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        #expect(three.merging(0, 2) == nil)
        #expect(three.merging(0, 0) == nil)
    }

    @Test func idsAreNeverMintedTwice() throws {
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        let merged = try #require(three.merging(1, 2)).split
        let again = try #require(merged.splitting(1, .sideBySide))
        #expect(again.areas.map(\.id) == [0, 1, 3])
    }

    @Test func nextIDSurvivesCoding() throws {
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        let merged = try #require(three.merging(1, 2)).split
        let data = try JSONEncoder().encode(merged)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"next_id\":3"))
        let back = try JSONDecoder().decode(ScreenSplit.self, from: data)
        #expect(back == merged)
    }

    @Test func evenOutAlongTheSplit() throws {
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        let even = three.evenedOut(width: 3440, height: 1440)
        #expect(even.areas.map(\.w) == [1147, 1147, 1146])
        #expect(even.areas.map(\.x) == [0, 1147, 2294])
        #expect(
            ScreenArea.problem(with: even.areas, width: 3440, height: 1440)
                == nil
        )
    }
}
