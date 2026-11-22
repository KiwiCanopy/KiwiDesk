import Foundation
import Testing

@testable import KiwiDeskCore

/// A screen's split (#3517): the area key's build and parse, and
/// the checks Lua refuses a broken list on.
@Suite("Screen areas")
struct ScreenAreaTests {
    private let fingerprint = "LG HDR WQHD:3440x1440"

    @Test func originalAreaKeepsTheBareFingerprint() {
        let key = ScreenAreaKey(fingerprint: fingerprint)
        #expect(key.description == fingerprint)
        #expect(ScreenAreaKey(parsing: fingerprint) == key)
    }

    @Test func otherAreasTakeTheSuffix() {
        let key = ScreenAreaKey(fingerprint: fingerprint, areaID: 2)
        #expect(key.description == "LG HDR WQHD:3440x1440#2")
        #expect(ScreenAreaKey(parsing: key.description) == key)
        #expect(
            Display.fingerprintParts(key.description).name
                == "LG HDR WQHD"
        )
    }

    @Test func hashInAScreenNameStaysWhole() {
        for raw in [
            "Dell #2:1920x1080", "Odd#3", "Odd:axb#3",
            "LG:3440x1440#0", "LG:3440x1440#-1", "LG:3440x1440#x",
        ] {
            let key = ScreenAreaKey(parsing: raw)
            #expect(key.areaID == 0, "\(raw)")
            #expect(key.fingerprint == raw, "\(raw)")
        }
    }

    private func area(
        _ id: Int,
        _ x: Int,
        _ y: Int,
        _ w: Int,
        _ h: Int
    ) -> ScreenArea {
        ScreenArea(id: id, x: x, y: y, w: w, h: h)
    }

    private func problem(_ areas: [ScreenArea]) -> ScreenAreaProblem? {
        ScreenArea.problem(with: areas, width: 3440, height: 1440)
    }

    @Test func exactTilingsPass() {
        #expect(problem([area(0, 0, 0, 3440, 1440)]) == nil)
        #expect(
            problem([
                area(0, 0, 0, 1720, 1440), area(1, 1720, 0, 1720, 1440),
            ]) == nil
        )
        #expect(
            problem([
                area(0, 0, 0, 3440, 720), area(4, 0, 720, 3440, 720),
            ]) == nil
        )
        #expect(
            problem([
                area(0, 0, 0, 1000, 1440), area(1, 1000, 0, 1440, 720),
                area(2, 1000, 720, 1440, 720), area(3, 2440, 0, 1000, 1440),
            ]) == nil
        )
    }

    @Test func brokenListsAreNamed() {
        #expect(problem([]) == .empty)
        #expect(
            problem([
                area(0, 0, 0, 1720, 1440), area(0, 1720, 0, 1720, 1440),
            ]) == .duplicateID(0)
        )
        #expect(problem([area(-1, 0, 0, 3440, 1440)]) == .negativeID(-1))
        #expect(
            problem([
                area(0, 0, 0, 3350, 1440), area(1, 3350, 0, 90, 1440),
            ]) == .tooSmall(id: 1)
        )
        #expect(
            problem([
                area(0, 0, 0, 1720, 1440), area(1, 1720, 0, 1800, 1440),
            ]) == .outsideScreen(id: 1)
        )
        #expect(
            problem([
                area(0, 0, 0, 1800, 1440), area(1, 1700, 0, 1740, 1440),
            ]) == .overlap(0, 1)
        )
        #expect(
            problem([
                area(0, 0, 0, 1700, 1440), area(1, 1720, 0, 1720, 1440),
            ]) == .gap
        )
    }

    @Test func readingOrderIsRowsThenColumns() {
        let order = ScreenArea.readingOrder([
            area(2, 0, 720, 3440, 720), area(1, 1720, 0, 1720, 720),
            area(0, 0, 0, 1720, 720),
        ]).map(\.id)
        #expect(order == [0, 1, 2])
    }
}
