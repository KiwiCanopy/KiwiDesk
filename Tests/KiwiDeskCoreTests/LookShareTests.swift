import Foundation
import Testing

@testable import KiwiDeskCore

/// Share current look's form address (#1740 ▸ Share): the gallery's
/// "Submit a look" form, the look file prefilled under the form's
/// own field ids, the credit in its `based_on` field.
@Suite("Look share")
struct LookShareTests {
    private func items(_ url: URL) -> [String: String] {
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var out: [String: String] = [:]
        for item in parts?.queryItems ?? [] {
            out[item.name] = item.value
        }
        return out
    }

    private func credited() -> TilingSettings {
        var settings = TilingSettings()
        ShelfLook(
            name: "Dusk",
            style: ["kiwishelf.thickness": .number(30)],
            colors: [:],
            author: "Anna"
        ).pick(into: &settings)
        return settings
    }

    @Test("the address opens the form with the file and credit")
    func formCarriesTheLook() throws {
        let share = LookShare(name: "Dusk & Dawn", settings: credited())
        let url = try #require(try share.prefilledURL(version: "4.1.0"))
        #expect(url.host == "github.com")
        #expect(url.path == "/KiwiCanopy/KiwiDesk-Looks/issues/new")
        let fields = items(url)
        #expect(fields["template"] == "submit-look.yml")
        #expect(fields["title"] == "Look: Dusk & Dawn")
        #expect(fields["version"] == "4.1.0")
        #expect(fields["based_on"] == "Dusk by Anna")
        let file = try #require(fields["look"])
        let back = try LookStore.importLook(data: Data(file.utf8))
        #expect(back.name == "Dusk & Dawn")
        #expect(back.basedOn == LookCredit(name: "Dusk", author: "Anna"))
        #expect(back.style == share.look.admitted.style)
    }

    @Test("a plus sign survives the form's query")
    func plusIsEscaped() {
        let share = LookShare(name: "A+B", settings: TilingSettings())
        let url = share.formURL(version: "4.1.0")
        // A form reads a bare `+` as a space, so it is sent escaped.
        let parts = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )
        let query = parts?.percentEncodedQuery ?? ""
        #expect(query.contains("A%2BB"))
        #expect(!query.contains("A+B"))
    }

    @Test("a share with no credit leaves the field out")
    func noCreditNoField() {
        let share = LookShare(name: "Mine", settings: TilingSettings())
        #expect(share.credit == nil)
        #expect(items(share.formURL(version: "4.1.0"))["based_on"] == nil)
    }

    @Test("the field names a gallery id, else the name and author")
    func basedOnFieldShapes() {
        var settings = TilingSettings()
        var look = ShelfLook(name: "Dusk", style: [:], colors: [:])
        look.basedOn = LookCredit(name: "Night", author: "Maya", id: "night")
        look.pick(into: &settings)
        let share = LookShare(name: "Mine", settings: settings)
        #expect(share.basedOnField == "night")
        look.basedOn = LookCredit(name: "Night")
        look.pick(into: &settings)
        let named = LookShare(name: "Mine", settings: settings)
        #expect(named.basedOnField == "Night")
    }

    @Test("past the address limit the file is left out")
    func longFileFallsBack() throws {
        var settings = TilingSettings()
        settings.kiwishelf.fontFamily = String(
            repeating: "Ä",
            count: LookShare.urlLimit
        )
        let share = LookShare(name: "Long", settings: settings)
        #expect(try share.prefilledURL(version: "4.1.0") == nil)
        #expect(items(share.formURL(version: "4.1.0"))["look"] == nil)
    }
}
