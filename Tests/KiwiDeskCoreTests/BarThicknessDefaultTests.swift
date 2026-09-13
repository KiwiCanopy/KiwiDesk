import Foundation
import Testing

@testable import KiwiDeskCore

/// The two bars ship ONE thickness, on every screen class
/// (#1359, owner ruling 2026-09-13).
///
/// The number itself is argued on `AppBarStyle.thickness` and
/// not pinned here — a retune is a docstring edit, not a red
/// suite. What is pinned is the shape: the Space Bar carries the
/// App Bar's number rather than its own, and the starter tuning
/// gives no screen class a thinner pair, which is where 28 lived
/// before the ruling.
@Suite("Bar thickness default")
struct BarThicknessDefaultTests {
    @Test("both bars ship the same thickness, clear of the floor")
    func barsAgree() {
        let app = AppBarStyle().thickness
        #expect(SpaceBarStyle().thickness == app)
        #expect(app > AppBarStyle.minThickness)
    }

    @Test("no screen class thins the starter's bars")
    func starterKeepsTheDefault() {
        for shape in ScreenClass.allCases {
            let tuned = StarterTuning.settings(mainShape: shape)
            #expect(
                tuned.appBarStyle.thickness == AppBarStyle().thickness,
                "\(shape)"
            )
            #expect(
                tuned.spaceBarStyle.thickness
                    == SpaceBarStyle().thickness,
                "\(shape)"
            )
        }
    }
}
