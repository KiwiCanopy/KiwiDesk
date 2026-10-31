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

    @Test("a refresh forgets a linked look the library dropped")
    func refreshForgets() throws {
        let model = makeTestModel()
        model.wearLinkedLook(try linked(model))
        try model.lookStore.delete("Dusk")
        model.refreshLooks()
        #expect(model.linkedLook == nil)
    }

    @Test("a fresh open forgets the linked look")
    func freshOpenForgets() throws {
        let model = makeTestModel()
        model.wearLinkedLook(try linked(model))
        model.prepareToShow(windowShown: true)
        #expect(model.linkedLook == "Dusk")
        model.prepareToShow(windowShown: false)
        #expect(model.linkedLook == nil)
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

    @Test("a rename keeps the look linked, so Simple keeps it")
    func renameKeepsTheLink() throws {
        let model = makeTestModel()
        model.wearLinkedLook(try linked(model))
        model.renameUserLook(from: "Dusk", to: "Dawn")
        #expect(model.linkedLook == "Dawn")
        #expect(SimpleLookCard.linked(in: model)?.name == "Dawn")
    }

    @Test("a delete drops the linked look from Simple's line")
    func deleteDropsTheLink() throws {
        let model = makeTestModel()
        model.wearLinkedLook(try linked(model))
        model.deleteUserLook("Dusk")
        #expect(model.linkedLook == nil)
        #expect(SimpleLookCard.linked(in: model) == nil)
    }

    /// Simple offers Delete on the gallery look alone (#2860): the
    /// one menu sits on the linked tile and holds no Rename.
    @Test("Simple's look menu is Delete on the linked tile alone")
    func simpleMenuIsDeleteOnly() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let card = try SourceScan.swiftSources(under: root)
            .first { $0.lastPathComponent == "SimpleLookCard.swift" }
        let source = try SourceScan.strippedSource(at: try #require(card))
            .filter { !$0.isWhitespace }
        #expect(source.occurrences(of: ".rowActions{") == 1)
        #expect(
            source.contains(
                "iflook.name==linked{tile(look).rowActions{menu(look)}"
            )
        )
        #expect(source.contains("L(\"looks.delete\""))
        #expect(!source.contains("L(\"looks.rename\""))
        // Delete alone: no Export or Share row beside it.
        #expect(!source.contains("L(\"looks.export"))
        #expect(!source.contains("L(\"looks.share"))
        // One write for both roots (gui.md ▸ shares its one write).
        #expect(source.contains("model.deleteUserLook(look.name)"))
        let shelf = try SourceScan.swiftSources(under: root)
            .first { $0.lastPathComponent == "LooksShelf+Actions.swift" }
        let shelfSource = try SourceScan.strippedSource(
            at: try #require(shelf)
        )
        #expect(shelfSource.contains("model.deleteUserLook(name)"))
    }
}
