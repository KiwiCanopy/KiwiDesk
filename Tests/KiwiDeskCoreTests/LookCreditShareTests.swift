import Foundation
import Testing

@testable import KiwiDeskCore

/// The credit rule (#1740): only the original's own settings
/// count, each once, and a look keeps its credit while half or more
/// are unchanged.
@Suite("Look credit share")
struct LookCreditShareTests {
    private func original() -> ShelfLook {
        ShelfLook(
            name: "Dusk",
            style: [
                "kiwishelf.thickness": .number(40),
                "border.width": .number(6),
                "border.corner_style": .string("square"),
            ],
            colors: ["border.focused_color": "#564AB6"]
        )
    }

    private func wearing(_ look: ShelfLook) -> TilingSettings {
        var settings = TilingSettings()
        look.admitted.apply(to: &settings)
        return settings
    }

    @Test("the look itself keeps every setting")
    func fullShare() {
        #expect(original().keptShare(in: wearing(original())) == 1)
    }

    @Test("each changed setting lowers the share")
    func changesLowerTheShare() throws {
        var settings = wearing(original())
        settings.kiwishelf.thickness = 30
        settings.borderStyle.width = 2
        #expect(original().keptShare(in: settings) == 0.5)
        #expect(original().stillCredited(by: settings))
        settings.borderStyle.cornerStyle = .rounded
        #expect(original().keptShare(in: settings) == 0.25)
        #expect(!original().stillCredited(by: settings))
    }

    @Test("settings the original does not set never count")
    func onlyItsOwnSettingsCount() {
        var settings = wearing(original())
        settings.kiwishelf.itemGap = 99
        #expect(original().keptShare(in: settings) == 1)
    }

    @Test("a colour counts by value, not spelling")
    func colourByValue() {
        var look = original()
        look.colors["border.focused_color"] = "#564ab6ff"
        #expect(look.keptShare(in: wearing(original())) == 1)
    }

    @Test("a look naming nothing credits nothing")
    func emptyLook() {
        let empty = ShelfLook(name: "E", style: [:], colors: [:])
        #expect(empty.keptShare(in: TilingSettings()) == 0)
    }
}
