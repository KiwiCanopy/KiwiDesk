import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A share cell's ↺ returns it to what a new profile stores (#3460):
/// 1280 pt on a wide shape, a fraction on Laptop, as the diff row
/// names it. Locale pinned per body (#740).
@MainActor
@Suite("Maximize length revert (#3460)")
struct MaximizeLengthRevertTests {
    @Test("a wide cell's ↺ restores 1280 pt")
    func wideCellRevertsToTheColumn() throws {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        model.cleanConfig = GuiConfig()
        var edited = GuiConfig()
        edited.settings.maximize.heightShare[.superUltrawide] =
            .fraction(1 / 4)
        edited.settings.maximize.heightShare[.laptop] = .points(1100)
        model.config = edited
        let rows = SettingsDiffRowSource.rows(for: model).filter {
            $0.key == .behaviour(.maximizeHeightShare)
        }
        let row = try #require(rows.first)
        #expect(row.oldValue == "75%")
        #expect(row.newValue == "1100 pt")
        #expect(model.canRevert(row))
        model.revert(row)
        let share = model.config.settings.maximize.heightShare
        #expect(share[.superUltrawide] == .points(1280))
        #expect(share[.laptop] == .fraction(3 / 4))
    }
}
