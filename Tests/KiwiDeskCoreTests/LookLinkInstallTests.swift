import Foundation
import Testing

@testable import KiwiDeskCore

/// A look a gallery link downloaded (#1740): added under a free
/// name, it keeps its gallery id, which a look started from it
/// credits and Share sends; an exported file leaves the id behind.
@Suite("Look link install", .serialized)
@MainActor
struct LookLinkInstallTests {
    private let link = LookLink(URL(string: "kiwidesk://look/dusk")!)!

    private func file(named name: String = "Dusk") throws -> Data {
        let look = ShelfLook(
            name: name,
            style: ["kiwishelf.thickness": .number(30)],
            colors: ["kiwishelf.fill_color": "#112233"],
            author: "Anna"
        )
        return try JSONEncoder().encode(LookExport(look: look))
    }

    @Test("an install keeps the author and the gallery id")
    func keepsTheID() throws {
        let core = try KeepFixture.core()
        let look = try core.installGalleryLook(
            file(),
            from: link,
            fallbackName: "My Look"
        )
        #expect(look.galleryID == "dusk")
        let stored = try core.lookLibrary.libraryLooks()
            .first { $0.name == "Dusk" }
        #expect(stored?.galleryID == "dusk")
        #expect(stored?.author == "Anna")
    }

    @Test("a second install of a taken name takes a free one")
    func freeName() throws {
        let core = try KeepFixture.core()
        try core.installGalleryLook(file(), from: link, fallbackName: "x")
        let second = try core.installGalleryLook(
            file(),
            from: link,
            fallbackName: "x"
        )
        #expect(second.name == "Dusk 2")
    }

    @Test("a look started from it credits the gallery id")
    func creditCarriesTheID() throws {
        let core = try KeepFixture.core()
        let look = try core.installGalleryLook(
            file(),
            from: link,
            fallbackName: "x"
        )
        var settings = TilingSettings()
        look.pick(into: &settings)
        let saved = try core.saveLook(named: "Mine", from: settings)
        #expect(
            saved.basedOn
                == LookCredit(name: "Dusk", author: "Anna", id: "dusk")
        )
        let share = LookShare(name: "Mine", settings: settings)
        #expect(share.basedOnField == "dusk")
    }

    @Test("an exported file leaves the gallery id behind")
    func exportDropsTheID() throws {
        var look = try LookStore.importLook(data: file())
        look.galleryID = "dusk"
        let data = try JSONEncoder().encode(LookExport(look: look))
        #expect(!String(decoding: data, as: UTF8.self).contains("gallery_id"))
        #expect(try LookStore.importLook(data: data).author == "Anna")
    }

    @Test("a file the gallery sent that is no look is refused")
    func refusesNoLook() throws {
        let core = try KeepFixture.core()
        #expect(throws: LookStore.StoreError.invalidFile) {
            try core.installGalleryLook(
                Data("<html></html>".utf8),
                from: link,
                fallbackName: "x"
            )
        }
        #expect(try core.lookLibrary.libraryLooks().isEmpty)
    }
}
