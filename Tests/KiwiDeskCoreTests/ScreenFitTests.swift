import Foundation
import Testing

@testable import KiwiDeskCore

/// The fit rule (#3647 ▸ no-fit ruling): a screen draws a number's
/// split only where no area falls under the floor along a cut, and a
/// setup is numbered in the first order that fits every screen.
@Suite("Screen fit (#3647)")
struct ScreenFitTests {
    private let wide = "Wide:3440x1440"
    private let laptop = "Laptop:1512x982"
    private let floors = AreaFloors(sideBySide: 800, stacked: 400)

    /// Screen 1 split side by side into halves.
    private var halves: [String: ScreenShares] {
        [
            "1": ScreenShares(
                areas: [
                    ScreenArea(id: 0, x: 0, y: 0, w: 500, h: 1000),
                    ScreenArea(id: 1, x: 500, y: 0, w: 500, h: 1000),
                ]
            )
        ]
    }

    @Test("a split narrower than the floor draws whole, naming its axis")
    func verdictNamesTheAxis() {
        let order = ScreenOrder([laptop, wide])
        #expect(
            halves.verdict(on: laptop, order: order, floors: floors)
                == .tooSmall(.sideBySide)
        )
        #expect(halves.split(on: laptop, order: order, floors: floors) == nil)
        let swapped = ScreenOrder([wide, laptop])
        #expect(
            halves.split(on: wide, order: swapped, floors: floors) != nil
        )
    }

    /// A side-by-side split on a short screen is judged on widths
    /// alone: its full-height areas are not cut along the height.
    @Test("an area is judged only along an axis it is cut along")
    func uncutAxisIsNotJudged() {
        let tall = AreaFloors(sideBySide: 100, stacked: 5000)
        let order = ScreenOrder([wide])
        #expect(halves.split(on: wide, order: order, floors: tall) != nil)
    }

    /// One per-mille step of the axis is given back for rounding.
    @Test("a split made at the floor passes after rounding")
    func floorSlackIsPerAxis() throws {
        // 803 of 3440 rounds back to 802.
        let floors = AreaFloors(sideBySide: 803, stacked: 400)
        let split = ScreenSplit(
            areas: [
                ScreenArea(id: 0, x: 0, y: 0, w: 803, h: 1440),
                ScreenArea(id: 1, x: 803, y: 0, w: 2637, h: 1440),
            ]
        )
        let back = ScreenShares(split, width: 3440, height: 1440)
            .resolved(width: 3440, height: 1440)
        try #require(back.areas[0].w < 803)
        #expect(
            ScreenSplit.verdict(
                back,
                width: 3440,
                height: 1440,
                floors: floors
            ).split != nil
        )
    }

    @Test("the base order stands where it fits")
    func fittingBaseStands() {
        let base = ScreenOrder([wide, laptop])
        #expect(base.fitting(halves, floors: floors) == base)
    }

    @Test("an unfit base takes the fitting order that moves fewest")
    func fittingSwaps() {
        let base = ScreenOrder([laptop, wide])
        #expect(!base.fits(halves, floors: floors))
        #expect(base.anyFits(halves, floors: floors))
        #expect(
            base.fitting(halves, floors: floors)
                == ScreenOrder([wide, laptop])
        )
    }

    @Test("where nothing fits, the base order stands")
    func nothingFitsKeepsTheBase() {
        let both = ScreenOrder([laptop, "Other:1000x900"])
        #expect(!both.anyFits(halves, floors: floors))
        #expect(both.fitting(halves, floors: floors) == both)
    }

    @Test("ties go to the order that comes first against the base")
    func tiesKeepTheBaseFirst() {
        let a = "A:3440x1440"
        let b = "B:3440x1440"
        let base = ScreenOrder([laptop, a, b])
        // [a, laptop, b] and [b, a, laptop] both move two numbers;
        // the first reads 1, 0, 2 against the base, the second 2, 1, 0.
        #expect(
            base.fitting(halves, floors: floors)
                == ScreenOrder([a, laptop, b])
        )
    }

    @Test("TilingSettings hands its floors along each cut")
    func settingsFloors() {
        let settings = TilingSettings()
        #expect(
            settings.areaFloors.sideBySide
                == settings.areaFloor(along: .sideBySide)
        )
        #expect(
            settings.areaFloors.stacked
                == settings.areaFloor(along: .stacked)
        )
    }
}
