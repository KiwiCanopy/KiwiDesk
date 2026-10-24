import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts side's direction glyphs (#2529 ▸ Ruling): a row
/// for one direction wears that direction, focus a line arrow and
/// swap a filled triangle; a folded set wears every direction it
/// covers, never its first member's one-sided glyph.
@Suite("Shortcut arrows show the directions a row covers")
@MainActor
struct ShortcutArrowShapeTests {
    private static let directions = ["left", "down", "up", "right"]

    /// The owner's picks for the folded sets (#2529 ▸ Ruling).
    private static let foldGlyphs: [ShortcutFold.Family: String] = [
        .focusDirections: "arrow.up.and.down.and.arrow.left.and.right",
        .swapDirections: "dpad.fill",
        .layoutCycle: "arrow.trianglehead.2.clockwise",
    ]

    private func folded(_ family: ShortcutFold.Family) -> ShortcutRow? {
        let members = ShortcutFold.sets(resizeStep: 50)
            .first { $0.0 == family }!.1
        let keys = ["a", "b", "c", "d"]
        let layer = KeyLayer(
            name: KeyLayer.defaultName,
            bindings: members.enumerated().map {
                KeyBinding(
                    combo: "option+command+\(keys[$0.offset])",
                    lua: $0.element.lua,
                    kind: .navigation
                )
            }
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        return reference.controls.flatMap(\.rows).first
    }

    @Test("a focus row wears its direction's line arrow")
    func focusRowsWearLineArrows() {
        let glyphs = KeybindingCatalog.focusDirections.map(
            ShortcutsReferenceBuilder.icon(for:)
        )
        #expect(glyphs == Self.directions.map { "arrow.\($0)" })
    }

    @Test("a swap row wears its direction's filled triangle")
    func swapRowsWearTriangles() {
        let glyphs = KeybindingCatalog.swapDirections.map(
            ShortcutsReferenceBuilder.icon(for:)
        )
        #expect(
            glyphs == Self.directions.map { "arrowtriangle.\($0).fill" }
        )
    }

    @Test("layout next and previous wear the cycle arrows")
    func layoutCycleRows() {
        let glyphs = KeybindingCatalog.layoutCycleRows.map(
            ShortcutsReferenceBuilder.icon(for:)
        )
        #expect(
            glyphs == [
                "arrow.trianglehead.clockwise",
                "arrow.trianglehead.counterclockwise",
            ]
        )
    }

    @Test("a folded set wears every direction, never a member's glyph")
    func foldedSetsWearTheirGroupGlyph() throws {
        LocalizationManager.shared.select("en")
        for (family, glyph) in Self.foldGlyphs {
            let row = try #require(folded(family), "\(family) built nothing")
            #expect(row.members.count >= 2, "\(family) did not fold")
            #expect(row.icon == glyph, "\(family) wears \(row.icon ?? "-")")
            let own = Set(row.members.compactMap(\.icon))
            #expect(!own.contains(row.icon ?? ""), "\(family)")
        }
    }

    /// Keyed on the catalog's commands, not a quoted direction in
    /// any Lua: a verb outside the focus and swap sets gains no arrow.
    @Test("a direction argument alone draws no arrow")
    func directionArgumentAloneDrawsNoArrow() {
        let other = NavCommand(
            label: "Focus screen to the left",
            lua: "KiwiDesk.focus_display(\"left\")"
        )
        #expect(ShortcutsReferenceBuilder.icon(for: other) == nil)
    }

    @Test("every fold glyph resolves on this macOS")
    func foldGlyphsResolve() {
        for family in ShortcutFold.Family.allCases {
            guard let glyph = ShortcutsReferenceBuilder.foldIcon(for: family)
            else { continue }
            #expect(
                NSImage(systemSymbolName: glyph, accessibilityDescription: nil)
                    != nil,
                "\(glyph) does not resolve"
            )
        }
        #expect(
            ShortcutFold.Family.allCases.contains {
                ShortcutsReferenceBuilder.foldIcon(for: $0) != nil
            }
        )
    }
}
