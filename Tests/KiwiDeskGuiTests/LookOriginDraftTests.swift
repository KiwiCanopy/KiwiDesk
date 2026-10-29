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
        LocalizationManager.shared.select("en")
        let model = makeTestModel(root: .advanced)
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

extension LookOriginDraftTests {
    @Test("the row names the credit a saved look kept, not its name")
    func rowNamesTheKeptCredit() {
        LocalizationManager.shared.select("en")
        let model = makeTestModel(root: .advanced)
        var saved = LookBody(of: model.config.settings).named("Mine")
        saved.basedOn = LookCredit(name: "Dawn", author: "Ben")
        model.applyLook(saved)
        let row = SettingsDiffRowSource.rows(for: model).first {
            $0.key == .colours(.lookOrigin)
        }
        #expect(row?.newValue == "Dawn by Ben")
    }
}
