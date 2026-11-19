import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Identical screens as macOS names them (#3351): `localizedName`
/// already reads "Twin (1)" / "Twin (2)", so twins are grouped by
/// the name without that numbering, and a lone screen whose name
/// ends in "(n)" keeps it.
@Suite("Identical screens are grouped by their bare name (#3351)")
struct ScreenTwinNameTests {
    @Test("the macOS numbering is dropped, nothing else")
    func baseName() {
        #expect(ScreenLabel.baseName("Twin (2)") == "Twin")
        #expect(ScreenLabel.baseName("DELL U2720Q (12)") == "DELL U2720Q")
        #expect(ScreenLabel.baseName("Twin") == "Twin")
        #expect(ScreenLabel.baseName("Twin (left)") == "Twin (left)")
        #expect(ScreenLabel.baseName("Twin()") == "Twin()")
        #expect(ScreenLabel.baseName("Twin(2)") == "Twin(2)")
        #expect(ScreenLabel.baseName(" (2)") == "")
        #expect(ScreenLabel.baseName("Twin (2) x") == "Twin (2) x")
        #expect(ScreenLabel.baseName("Twin (٢)") == "Twin (٢)")
    }

    private static func place(
        _ key: Int,
        _ name: String,
        x: CGFloat,
        y: CGFloat = 0
    ) -> (key: Int, name: String, frame: CGRect) {
        (key, name, CGRect(x: x, y: y, width: 100, height: 100))
    }

    @Test("numbered twins side by side read left and right")
    func numberedTwinsSideBySide() {
        let found = ScreenShiftPlan.namePositions([
            Self.place(1, "Twin (2)", x: 0),
            Self.place(2, "Twin (1)", x: 100),
            Self.place(3, "Mac", x: 200),
        ])
        #expect(found == [1: .left, 2: .right])
    }

    @Test("numbered twins stacked read above and below")
    func numberedTwinsStacked() {
        let found = ScreenShiftPlan.namePositions([
            Self.place(1, "Twin (1)", x: 0, y: 100),
            Self.place(2, "Twin (2)", x: 0, y: 0),
        ])
        #expect(found == [1: .below, 2: .above])
    }

    @Test("a lone screen named with a number takes no position")
    func loneNumberedName() {
        let found = ScreenShiftPlan.namePositions([
            Self.place(1, "Studio (2)", x: 0),
            Self.place(2, "Mac", x: 100),
        ])
        #expect(found.isEmpty)
    }
}
