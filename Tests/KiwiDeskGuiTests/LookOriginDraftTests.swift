import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A Settings pick records the look's origin in the draft (#1740),
/// so Save keeps it and Revert takes it back, and the save pill
/// narrates it as its own row.
@Suite("Look origin in the draft")
@MainActor
struct LookOriginDraftTests {
    private func authored(_ settings: TilingSettings) -> ShelfLook {
        var look = LookBody(of: settings).named("Dusk")
        look.author = "Anna"
        return look
    }

    @Test("a pick of an authored look writes the origin to the draft")
    func pickWritesTheDraft() {
        let model = makeTestModel()
        model.applyLook(authored(model.config.settings))
        #expect(model.config.settings.lookOrigin?.author == "Anna")
        #expect(model.isDirty)
        let rows = SettingsDiffRowSource.rows(for: model)
        let origin = rows.first {
            $0.key == .colours(.lookOrigin)
        }
        #expect(origin?.newValue == "Dusk by Anna")
    }

    @Test("a pick of an own look clears the draft's origin")
    func ownPickClears() {
        let model = makeTestModel()
        model.applyLook(authored(model.config.settings))
        model.applyLook(LookBody(of: model.config.settings).named("Mine"))
        #expect(model.config.settings.lookOrigin == nil)
    }
}
