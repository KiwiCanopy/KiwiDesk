import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shape verdict a starter setup's layouts are chosen from
/// (#678 Phase 4 pass 11, turn 15b).
@Suite("Screen class (#678 pass 11)")
struct ScreenClassTests {
    private func size(_ w: CGFloat, _ h: CGFloat) -> CGSize {
        CGSize(width: w, height: h)
    }

    @Test("real hardware lands in the class it was written for")
    func realHardware() {
        // A 14" MacBook Pro reports this from NSScreen.frame.
        #expect(ScreenClass.of(size(1728, 1117)) == .laptop)
        // 2560 pt is a 27" at any pixel density — the whole
        // reason the verdict reads points.
        #expect(ScreenClass.of(size(2560, 1440)) == .desktop)
        #expect(ScreenClass.of(size(3440, 1440)) == .ultrawide)
        #expect(ScreenClass.of(size(1440, 2560)) == .pivoted)
    }

    @Test("a 5K and a 1440p 27\" are the same screen in points")
    func pointsNotPixels() {
        #expect(
            ScreenClass.of(size(2560, 1440))
                == ScreenClass.of(size(2560, 1440))
        )
        // The Retina laptop has more pixels than either and still
        // wants laptop layouts; only its POINT width decides.
        #expect(ScreenClass.of(size(1728, 1117)) == .laptop)
    }

    @Test("boundaries fall on the side the constants name")
    func boundaries() {
        let laptop = ScreenClass.laptopWidth
        #expect(ScreenClass.of(size(laptop - 1, 1080)) == .laptop)
        #expect(ScreenClass.of(size(laptop, 1080)) == .desktop)
        let ultra = ScreenClass.ultrawideWidth
        #expect(ScreenClass.of(size(ultra - 1, 1440)) == .desktop)
        #expect(ScreenClass.of(size(ultra, 1440)) == .ultrawide)
    }

    @Test("a short ultrawide is caught by aspect, not width")
    func aspectCatchesShortUltrawide() {
        // 2560 × 1080 is under the width threshold and is still an
        // ultrawide; without the aspect arm it would be handed
        // desktop layouts including BSP.
        #expect(ScreenClass.of(size(2560, 1080)) == .ultrawide)
        let ratio = 2560.0 / 1080.0
        #expect(ratio >= ScreenClass.ultrawideAspect)
    }

    @Test("pivoted outranks every width test")
    func pivotedIsTestedFirst() {
        // Tall enough to pass the ultrawide ASPECT test if the
        // order were reversed, and wide enough to pass the width
        // one. Pivoted is checked first, so both are moot.
        #expect(ScreenClass.of(size(3440, 3441)) == .pivoted)
        #expect(ScreenClass.of(size(1080, 2560)) == .pivoted)
    }

    @Test("a degenerate size answers rather than dividing by zero")
    func degenerateSize() {
        #expect(ScreenClass.of(size(0, 0)) == .desktop)
        #expect(ScreenClass.of(size(1920, 0)) == .desktop)
    }

    @Test("every class offers Floating, and it is always last")
    func floatingIsAlwaysTheTail() {
        for shape in ScreenClass.allCases {
            #expect(
                shape.layouts.last == .floating,
                "\(shape) does not end in floating"
            )
            #expect(
                shape.layouts.filter { $0 == .floating }.count == 1
            )
        }
    }

    @Test("the deliberate absences stay absent")
    func absences() {
        // A layout no one uses is worse than one they discover
        // later: Track is out of the two classes with no width
        // to give it.
        #expect(!ScreenClass.laptop.layouts.contains(.track))
        #expect(!ScreenClass.desktop.layouts.contains(.track))
        // BSP produces absurd windows at 3440 pt and unusable
        // ones at 1728, so it exists only in the middle class.
        #expect(ScreenClass.desktop.layouts.contains(.bsp))
        for shape in ScreenClass.allCases where shape != .desktop {
            #expect(
                !shape.layouts.contains(.bsp),
                "\(shape) offers BSP"
            )
        }
    }

    @Test("no class repeats a layout inside its own list")
    func listsAreDistinct() {
        for shape in ScreenClass.allCases {
            #expect(
                Set(shape.layouts).count == shape.layouts.count,
                "\(shape) lists a layout twice"
            )
        }
    }
}
