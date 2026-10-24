import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts side's direction glyphs (#2529 ▸ Ruling): a row
/// for one direction wears that direction, focus and swap in
/// different shapes; a folded set wears every direction it covers,
/// never a member's glyph. The picks themselves are the docstrings'
/// in `ShortcutsReference+Glyphs.swift`; this suite holds shapes.
/// Main-actor spend: three builder passes and one symbol lookup per
/// family.
@Suite("Shortcut arrows show the directions a row covers")
@MainActor
struct ShortcutArrowShapeTests {
    /// The sets whose members each name a direction.
    private static let directional: [ShortcutFold.Family] = [
        .focusDirections, .swapDirections, .layoutCycle,
    ]

    private func folded(
        _ family: ShortcutFold.Family
    ) throws -> ShortcutRow {
        let members = try #require(
            ShortcutFold.sets(resizeStep: 50).first { $0.0 == family }?.1,
            "\(family) is not a set"
        )
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
        return try #require(
            reference.controls.flatMap(\.rows).first,
            "\(family) built nothing"
        )
    }

    /// A glyph's name parts, so "left" matches `arrow.left` and not
    /// a name that merely contains the letters.
    private func parts(_ glyph: String?) -> Set<Substring> {
        Set((glyph ?? "").split(separator: "."))
    }

    @Test("a focus or swap row names its own direction alone")
    func singleRowsNameTheirDirection() {
        let names = KeybindingCatalog.directionNames
        for commands in [
            KeybindingCatalog.focusDirections,
            KeybindingCatalog.swapDirections,
        ] {
            for (command, name) in zip(commands, names) {
                let glyph = ShortcutsReferenceBuilder.icon(for: command)
                let named = parts(glyph).intersection(
                    names.map { Substring($0) }
                )
                #expect(named == [Substring(name)], "\(command.lua)")
            }
        }
    }

    @Test("focus and swap wear different shapes")
    func focusAndSwapDiffer() {
        let focus = Set(
            KeybindingCatalog.focusDirections.compactMap(
                ShortcutsReferenceBuilder.icon(for:)
            )
        )
        let swap = Set(
            KeybindingCatalog.swapDirections.compactMap(
                ShortcutsReferenceBuilder.icon(for:)
            )
        )
        #expect(focus.count == 4 && swap.count == 4)
        #expect(focus.isDisjoint(with: swap))
    }

    @Test("a folded set wears its own glyph, never a member's")
    func foldedSetsWearTheirGroupGlyph() throws {
        LocalizationManager.shared.select("en")
        for family in Self.directional {
            let row = try folded(family)
            #expect(row.members.count >= 2, "\(family) did not fold")
            let glyph = try #require(row.icon, "\(family) is bare")
            #expect(
                glyph == ShortcutsReferenceBuilder.foldIcon(for: family),
                "\(family) wears \(glyph)"
            )
            let own = Set(row.members.compactMap(\.icon))
            #expect(!own.contains(glyph), "\(family)")
        }
    }

    /// Keyed on the catalog's commands, not a quoted direction in
    /// any Lua: a verb outside the focus and swap sets gains no arrow.
    @Test("a direction argument alone draws no arrow")
    func directionArgumentAloneDrawsNoArrow() {
        for name in KeybindingCatalog.directionNames {
            let other = NavCommand(
                label: "Focus screen \(name)",
                lua: "KiwiDesk.focus_display(\"\(name)\")"
            )
            #expect(
                ShortcutsReferenceBuilder.icon(for: other) == nil,
                "\(name)"
            )
        }
    }

    @Test("every fold glyph resolves on this macOS")
    func foldGlyphsResolve() {
        let glyphs = ShortcutFold.Family.allCases.compactMap(
            ShortcutsReferenceBuilder.foldIcon(for:)
        )
        #expect(!glyphs.isEmpty)
        for glyph in glyphs {
            #expect(
                NSImage(
                    systemSymbolName: glyph,
                    accessibilityDescription: nil
                ) != nil,
                "\(glyph) does not resolve"
            )
        }
    }
}
