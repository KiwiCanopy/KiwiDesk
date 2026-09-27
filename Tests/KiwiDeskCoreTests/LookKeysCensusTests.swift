import Foundation
import Testing

@testable import KiwiDeskCore

/// The look's styling register (#1684, owner ruling 2026-09-27):
/// styling in, functionality and colour out, and every shelf field
/// classified so a new one reds until someone rules it.
@Suite("Look keys census")
struct LookKeysCensusTests {
    @Test("every KiwiShelf key is a look's, a palette's or left out")
    func everyShelfKeyIsClassified() {
        let colours = Set(
            ColorPaletteKeys.all.filter { $0.hasPrefix("kiwishelf.") }
                .map { String($0.dropFirst("kiwishelf.".count)) }
        )
        let looks = Set(LookKeys.shelfFields)
        let leftOut = Set(LookKeys.leftOut.keys)
        for key in KiwiShelf.CodingKeys.allCases.map(\.stringValue) {
            let homes = [looks, colours, leftOut].filter {
                $0.contains(key)
            }
            #expect(
                homes.count == 1,
                "kiwishelf.\(key) is in \(homes.count) homes; rule it"
            )
        }
    }

    @Test("functionality and colour never join the register")
    func functionalityStaysOut() {
        let all = Set(LookKeys.all)
        for path in [
            "app_bar.content", "space_bar.inactive_content",
            "space_bar.enabled", "space_bar.show_front_app",
            "space_bar.hide_empty", "app_bar.title_cap",
        ] {
            #expect(!all.contains(path), "\(path) is functionality")
        }
        #expect(all.isDisjoint(with: ColorPaletteKeys.all))
    }

    @Test("the ruled styling fields are in the register")
    func ruledFieldsAreIn() {
        let all = Set(LookKeys.all)
        for path in [
            "kiwishelf.edge", "kiwishelf.background_fit",
            "kiwishelf.corner_roundness", "kiwishelf.thickness",
            "kiwishelf.outer_margin", "kiwishelf.liquid_glass",
            "kiwishelf.background_style", "kiwishelf.border",
            "kiwishelf.border_width", "kiwishelf.font_family",
            "kiwishelf.font_weight", "kiwishelf.glyph_size",
            "space_bar.active_indicator", "app_bar.active_indicator",
            "border.sheen", "kiwishelf.order", "kiwishelf.alignment",
        ] {
            #expect(all.contains(path), "\(path) is ruled styling")
        }
    }

    @Test("every register path extracts from the settings")
    func everyPathExtracts() {
        let extracted = LookKeys.extract(from: TilingSettings())
        #expect(Set(extracted.keys) == Set(LookKeys.all))
    }
}
