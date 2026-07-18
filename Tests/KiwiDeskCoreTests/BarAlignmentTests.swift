import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The bar `alignment` knob (#293 QA): the App Bar's
/// `frames()` group placement and the Space Bar's
/// `contentStart` — start / center / end while the run fits,
/// collapsing once it can't.
@Suite("Bar alignment")
struct BarAlignmentTests {
    private let bounds = CGRect(
        x: 0,
        y: 0,
        width: 320,
        height: 32
    )

    @Test("Fitting frames start at zero for start alignment")
    func framesStart() {
        let frames = AppBarOverlay.frames(
            lengths: [100, 100],
            in: bounds,
            gap: 10,
            horizontal: true,
            alignment: .start
        )
        #expect(frames[0].minX == 0)
        #expect(frames[1].minX == 110)
    }

    @Test("Fitting frames end at the axis for end alignment")
    func framesEnd() {
        let frames = AppBarOverlay.frames(
            lengths: [100, 100],
            in: bounds,
            gap: 10,
            horizontal: true,
            alignment: .end
        )
        // 210 used of 320: the group starts at 110.
        #expect(frames[0].minX == 110)
        #expect(frames[1].maxX == 320)
    }

    @Test("Vertical end alignment seats the group at maxY")
    func framesEndVertical() {
        let frames = AppBarOverlay.frames(
            lengths: [40, 40],
            in: CGRect(x: 0, y: 0, width: 32, height: 100),
            gap: 0,
            horizontal: false,
            alignment: .end
        )
        #expect(frames[0].minY == 20)
        #expect(frames[1].maxY == 100)
    }

    @Test("Overflow collapses every alignment to the offset")
    func overflowCollapses() {
        for alignment in AppBarStyle.BarAlignment.allCases {
            let frames = AppBarOverlay.frames(
                lengths: Array(repeating: 100, count: 10),
                in: bounds,
                gap: 0,
                horizontal: true,
                alignment: alignment,
                scrolledBy: 250
            )
            #expect(frames[0].minX == -250)
        }
    }

    @Test("Space Bar content start honors alignment and pad")
    func spaceBarContentStart() {
        #expect(
            SpaceBarOverlay.contentStart(
                total: 100,
                axis: 320,
                alignment: .start,
                pad: 4
            ) == 4
        )
        #expect(
            SpaceBarOverlay.contentStart(
                total: 100,
                axis: 320,
                alignment: .center,
                pad: 4
            ) == 110
        )
        #expect(
            SpaceBarOverlay.contentStart(
                total: 100,
                axis: 320,
                alignment: .end,
                pad: 4
            ) == 216
        )
    }

    @Test("Oversized Space Bar run falls back to the pad")
    func spaceBarOverflowFloorsAtPad() {
        for alignment in SpaceBarStyle.Alignment.allCases {
            #expect(
                SpaceBarOverlay.contentStart(
                    total: 500,
                    axis: 320,
                    alignment: alignment,
                    pad: 4
                ) == 4
            )
        }
    }
}
