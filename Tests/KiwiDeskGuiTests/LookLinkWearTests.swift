import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

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
        try model.core.lookLibrary.save(look)
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
        #expect(SimpleLookCard.looks(in: model).first?.name == "Dusk")
    }

    /// #2943: the line held one gallery look, so a second link and a
    /// fresh open each dropped the earlier one from Simple.
    @Test("Simple's line leads with every look, newest first")
    func everyLookLeads() throws {
        let model = makeTestModel()
        let dusk = try linked(model)
        var dawn = LookBody(of: model.config.settings).named("Dawn")
        dawn.galleryID = "dawn"
        try model.core.lookLibrary.save(dawn)
        try model.core.lookLibrary.save(
            LookBody(of: model.config.settings).named("Mine")
        )
        model.wearLinkedLook(dusk)
        model.prepareToShow(windowShown: false)
        let bundled = model.core.bundledLooks.map(\.name)
        #expect(
            SimpleLookCard.looks(in: model).map(\.name)
                == ["Mine", "Dawn", "Dusk"] + bundled
        )
    }

    @Test("a rename keeps the look's place on Simple's line")
    func renameKeepsThePlace() throws {
        let model = makeTestModel()
        model.wearLinkedLook(try linked(model))
        try model.core.lookLibrary.save(
            LookBody(of: model.config.settings).named("Mine")
        )
        model.refreshLooks()
        model.renameUserLook(from: "Dusk", to: "Dawn")
        #expect(
            SimpleLookCard.mine(in: model).map(\.name) == ["Mine", "Dawn"]
        )
    }

    @Test("a delete drops the look from Simple's line")
    func deleteDropsTheLook() throws {
        let model = makeTestModel()
        model.wearLinkedLook(try linked(model))
        model.deleteUserLook("Dusk")
        #expect(SimpleLookCard.mine(in: model).isEmpty)
    }

    /// Simple offers Rename and Delete on each user look (#2860,
    /// #2943): one menu, on the user's tiles, through Advanced's writes.
    @Test("Simple's look menu is Rename and Delete on the user's looks")
    func simpleMenuIsRenameAndDelete() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let card = try SourceScan.swiftSources(under: root)
            .first { $0.lastPathComponent == "SimpleLookCard.swift" }
        let source = try SourceScan.strippedSource(at: try #require(card))
            .filter { !$0.isWhitespace }
        #expect(source.occurrences(of: ".rowActions{") == 1)
        #expect(source.contains("mine:Self.mine(in:model)"))
        #expect(source.contains(".rowActions{menu(look,in:entries)}"))
        // The line's order: My looks, the hairline only while one
        // exists, then the bundled looks (#2943 ruling 2).
        #expect(
            source.contains(
                "mine.map(Entry.mine)+(mine.isEmpty?[]:[.hairline])"
                    + "+bundled.map(Entry.bundled)+[.browse]"
            )
        )
        #expect(source.contains("bundled:model.core.bundledLooks"))
        #expect(
            source.contains("case.bundled(letlook):tile(look,id:entry.id)")
        )
        #expect(source.contains("case.hairline:Divider()"))
        #expect(source.contains("case.browse:browseTile"))
        #expect(source.contains("L(\"looks.delete\""))
        #expect(source.contains("L(\"looks.rename\""))
        // No Export or Share row beside them.
        #expect(!source.contains("L(\"looks.export"))
        #expect(!source.contains("L(\"looks.share"))
        // One write for both roots (gui.md ▸ shares its one write).
        #expect(source.contains("model.deleteUserLook(look.name)"))
        #expect(source.contains("model.renameUserLook(from:old,to:name)"))
        let shelf = try SourceScan.swiftSources(under: root)
            .first { $0.lastPathComponent == "LooksShelf+Actions.swift" }
        let shelfSource = try SourceScan.strippedSource(
            at: try #require(shelf)
        )
        #expect(shelfSource.contains("model.deleteUserLook(name)"))
        // One rename popover for both roots.
        #expect(source.contains("LooksShelf.renamePopover(request,"))
        #expect(!source.contains("NameEditPopover("))
    }

    /// #2943: a re-add downloaded first, so offline it failed though
    /// My looks held the look.
    @Test("a link asks for the held look before it downloads")
    func heldBeforeFetch() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let file = try SourceScan.swiftSources(under: root)
            .first { $0.lastPathComponent == "AppDelegate+LookLink.swift" }
        let source = try SourceScan.strippedSource(at: try #require(file))
            .filter { !$0.isWhitespace }
        let held = try #require(
            source.range(
                of: "ifletheld=core.heldGalleryLook(for:link){wear(held)"
            )
        )
        let fetch = try #require(source.range(of: "link.fetch"))
        #expect(held.lowerBound < fetch.lowerBound)
    }
}
