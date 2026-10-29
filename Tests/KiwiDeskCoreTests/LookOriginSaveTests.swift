import Foundation
import Testing

@testable import KiwiDeskCore

/// A pick and a save through the core (#1740): `look.apply` records
/// an authored look's origin on the live settings, and saving the
/// current look keeps the credit it still earns as `based_on`.
@Suite("Look origin through the core", .serialized)
@MainActor
struct LookOriginSaveTests {
    private func authored() -> ShelfLook {
        ShelfLook(
            name: "Dusk",
            style: ["kiwishelf.thickness": .number(30)],
            colors: ["kiwishelf.fill_color": "#112233"],
            author: "Anna"
        )
    }

    @Test("look.apply of an authored look records its origin")
    func applyVerbRecords() throws {
        let core = try KeepFixture.core()
        try core.lookLibrary.save(authored())
        let response = core.execute("look.apply", args: [.string("Dusk")])
        #expect(response.isSuccess)
        #expect(core.tiler.settings.lookOrigin?.author == "Anna")
    }

    @Test("a save keeps the credit the origin still earns")
    func saveKeepsTheCredit() throws {
        let core = try KeepFixture.core()
        var settings = TilingSettings()
        authored().pick(into: &settings)
        let saved = try core.saveLook(named: "Mine", from: settings)
        #expect(saved.basedOn == LookCredit(name: "Dusk", author: "Anna"))
        #expect(saved.author == nil)
        let stored = try core.lookLibrary.libraryLooks()
            .first { $0.name == "Mine" }
        #expect(stored?.basedOn == saved.basedOn)
    }

    @Test("a save from settings with no origin credits no one")
    func saveWithoutOrigin() throws {
        let core = try KeepFixture.core()
        let saved = try core.saveLook(
            named: "Plain",
            from: TilingSettings()
        )
        #expect(saved.basedOn == nil)
    }
}
