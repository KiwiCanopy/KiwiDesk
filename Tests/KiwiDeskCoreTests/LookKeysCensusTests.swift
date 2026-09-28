import Foundation
import Testing

@testable import KiwiDeskCore

/// The look's styling register (#1684, owner ruling 2026-09-27):
/// styling in, functionality and colour out, and every shelf field
/// classified so a new one reds until someone rules it.
@Suite("Look keys census")
struct LookKeysCensusTests {
    @Test("every field a look reaches is a look's, a palette's or left out")
    func everyFieldIsClassified() {
        let paths =
            KiwiShelf.CodingKeys.allCases.map { "kiwishelf.\($0.stringValue)" }
            + SpaceBarStyle.CodingKeys.allCases.map {
                "space_bar.\($0.stringValue)"
            }
            + AppBarStyle.CodingKeys.allCases.map {
                "app_bar.\($0.stringValue)"
            }
            + BorderStyle.CodingKeys.allCases.map {
                "border.\($0.stringValue)"
            }
            + TilingSettings.GapKeys.allCases.map {
                "gap.\($0.stringValue)"
            }
        #expect(paths.count > 40)
        let homes = [
            Set(LookKeys.all), Set(ColorPaletteKeys.all),
            Set(LookKeys.leftOut.keys),
        ]
        for path in paths {
            let count = homes.filter { $0.contains(path) }.count
            #expect(count == 1, "\(path) is in \(count) homes; rule it")
        }
        // Every entry names a real field, so none outlives its field.
        #expect(Set(LookKeys.leftOut.keys).isSubset(of: Set(paths)))
    }

    @Test("functionality and colour never join the register")
    func functionalityStaysOut() {
        let all = Set(LookKeys.all)
        for path in [
            "app_bar.content", "space_bar.inactive_content",
            "space_bar.enabled", "space_bar.show_front_app",
            "space_bar.hide_empty", "app_bar.title_cap",
            "border.enabled", "border.unfocused_enabled",
            "border.draw_order", "gap.override",
        ] {
            #expect(!all.contains(path), "\(path) is functionality")
        }
        #expect(all.isDisjoint(with: ColorPaletteKeys.all))
    }

    @Test("the ruled styling fields are in the register")
    func ruledFieldsAreIn() {
        let all = Set(LookKeys.all)
        for path in [
            "space_bar.edge", "app_bar.edge",
            "kiwishelf.background_fit",
            "kiwishelf.corner_roundness", "kiwishelf.thickness",
            "kiwishelf.outer_margin", "kiwishelf.liquid_glass",
            "kiwishelf.background_style", "kiwishelf.border",
            "kiwishelf.border_width", "kiwishelf.font_family",
            "kiwishelf.font_weight", "kiwishelf.glyph_size",
            "space_bar.active_indicator", "app_bar.active_indicator",
            "border.sheen", "kiwishelf.order", "kiwishelf.alignment",
            // #1739: the focus border's shape and the global gaps.
            "border.width", "border.corner_style", "border.glow",
            "border.glow_size", "gap.global",
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
