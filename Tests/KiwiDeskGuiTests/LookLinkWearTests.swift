import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A look a gallery link added is worn as an unsaved change with its
/// tile marked, in Simple and Advanced alike (#1740 ▸ Step 3
/// decisions).
@Suite("Look link in Settings")
@MainActor
struct LookLinkWearTests {
    private func linked(_ model: SettingsModel) throws -> ShelfLook {
        var look = LookBody(of: model.config.settings).named("Dusk")
        look.style["kiwishelf.thickness"] = .number(41)
        look.author = "Anna"
        look.galleryID = "dusk"
        try model.lookStore.save(look)
        return look
    }

    @Test("the look is worn unsaved and its tile reads applied")
    func wornUnsaved() throws {
        let model = makeTestModel()
        let look = try linked(model)
        model.wearLinkedLook(look)
        #expect(model.isDirty)
        #expect(model.config.settings.lookOrigin?.galleryID == "dusk")
        #expect(look.match(model.config.settings) != .none)
        #expect(model.userLooks.contains { $0.name == "Dusk" })
    }

    @Test("Advanced lands on the Looks page")
    func advancedLands() throws {
        let model = makeTestModel()
        model.settingsRoot = .advanced
        model.wearLinkedLook(try linked(model))
        #expect(
            model.nav.pendingReveal
                == SettingsAnchor(destination: .looks)
        )
    }

    @Test("Simple stays on Simple, its line led by the look")
    func simpleStays() throws {
        let model = makeTestModel()
        model.settingsRoot = .simple
        model.wearLinkedLook(try linked(model))
        #expect(model.showsSimple)
        #expect(model.nav.pendingReveal == nil)
        #expect(model.linkedLook == "Dusk")
        #expect(SimpleLookCard.looks(in: model).first?.name == "Dusk")
    }

    @Test("Simple's line drops a linked look My looks no longer holds")
    func simpleDropsAGoneLook() {
        let model = makeTestModel()
        model.linkedLook = "Gone"
        #expect(
            SimpleLookCard.looks(in: model).map(\.name)
                == model.core.bundledLooks.map(\.name)
        )
    }
}
