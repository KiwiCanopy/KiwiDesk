import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The park corner is the bottom corner whose parked window covers
/// less of the other screens, counting screens below as well as
/// beside, with bottom-right on a tie (#3335). Frames are AX
/// visible frames: y grows down, so a screen above has a
/// negative y.
@Suite("Park corner scoring (#3335)")
struct ParkCornerScoringTests {
    private func corner(
        of screen: CGRect,
        among others: [CGRect]
    ) -> TilingEngine.HideCorner {
        TilingEngine.optimalHideCorner(for: screen, among: others)
    }

    @Test("A screen above another parks away from the lower one")
    func screenAbove() {
        // The lower screen sits under the upper one's right
        // half, so a bottom-right park drops onto it.
        let upper = CGRect(x: 0, y: -1200, width: 2000, height: 1200)
        let lower = CGRect(x: 500, y: 0, width: 1500, height: 1000)
        #expect(corner(of: upper, among: [upper, lower]) == .bottomLeft)
        #expect(
            TilingEngine.parkOverlap(
                of: upper,
                at: .bottomRight,
                on: [lower]
            ) > 0
        )
        #expect(
            TilingEngine.parkOverlap(
                of: upper,
                at: .bottomLeft,
                on: [lower]
            ) == 0
        )
    }

    @Test("A shorter middle screen parks toward the lesser overlap")
    func shorterMiddle() {
        // Both bottom corners touch a neighbour; the left one
        // reaches only 100 pt below the middle, the right one
        // 1000 pt.
        let left = CGRect(x: -1000, y: 0, width: 1000, height: 1100)
        let middle = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 2000)
        #expect(
            corner(of: middle, among: [left, middle, right])
                == .bottomLeft
        )
    }

    @Test("The owner's desk keeps the corners it parks in today")
    func ownersDesk() {
        // A 1728×1117 laptop with a 2560×1440 screen to its right,
        // raised 159 pt.
        let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let dell = CGRect(x: 1728, y: -159, width: 2560, height: 1440)
        let screens = [laptop, dell]
        #expect(corner(of: laptop, among: screens) == .bottomLeft)
        #expect(corner(of: dell, among: screens) == .bottomRight)
        // The Dell's bottom-left park clears the laptop's bottom.
        #expect(
            TilingEngine.parkOverlap(
                of: dell,
                at: .bottomLeft,
                on: [laptop]
            ) == 0
        )
    }

    @Test("A lone screen parks bottom-right")
    func loneScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        #expect(corner(of: screen, among: []) == .bottomRight)
        // The screen's own rect in the list is not a neighbour.
        #expect(corner(of: screen, among: [screen]) == .bottomRight)
    }

    @Test("An even overlap on both corners ties to bottom-right")
    func tie() {
        // Boxed in: a wide screen directly below covers both
        // corners alike.
        let upper = CGRect(x: 0, y: -1000, width: 1000, height: 1000)
        let lower = CGRect(x: -500, y: 0, width: 2000, height: 1000)
        let left = TilingEngine.parkOverlap(
            of: upper,
            at: .bottomLeft,
            on: [lower]
        )
        #expect(left > 0)
        #expect(
            left
                == TilingEngine.parkOverlap(
                    of: upper,
                    at: .bottomRight,
                    on: [lower]
                )
        )
        #expect(corner(of: upper, among: [lower]) == .bottomRight)
    }

    @Test("A layout's park reads the scored corner")
    func layoutParkReadsTheScore() {
        // Monocle and a run park through the neighbours the
        // engine threads (#881), so they must carry the score.
        let upper = CGRect(x: 0, y: -1200, width: 2000, height: 1200)
        let lower = CGRect(x: 500, y: 0, width: 1500, height: 1000)
        let neighbors = TilingEngine.screenNeighbors(
            around: upper,
            among: [upper, lower]
        )
        #expect(neighbors.bottom)
        #expect(
            TilingEngine.optimalHideCorner(neighbors: neighbors)
                == .bottomLeft
        )
    }
}
