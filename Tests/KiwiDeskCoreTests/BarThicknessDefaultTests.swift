import Foundation
import Testing

@testable import KiwiDeskCore

/// The shelf ships ONE thickness, on every screen class (#1359,
/// owner ruling 2026-09-13; one store since #1517).
///
/// The number itself is argued on `KiwiShelf.thickness` and not
/// pinned here — a retune is a docstring edit, not a red suite.
/// What is pinned is the shape: the default clears the floor, and
/// the starter tuning gives no screen class a thinner shelf,
/// which is where 28 lived before the ruling.
@Suite("Bar thickness default")
struct BarThicknessDefaultTests {
    @Test("the shelf's default clears the floor")
    func clearOfTheFloor() {
        #expect(KiwiShelf().thickness > KiwiShelf.minThickness)
    }

    @Test("no screen class thins the starter's shelf")
    func starterKeepsTheDefault() {
        for shape in ScreenClass.allCases {
            let tuned = StarterTuning.settings(
                mainShape: shape,
                hosts: [:]
            )
            #expect(
                tuned.kiwishelf.thickness == KiwiShelf().thickness,
                "\(shape)"
            )
        }
    }
}
