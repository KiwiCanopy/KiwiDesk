import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shortcuts panel's gesture column (#3380 ▸ Ruling): a family
/// reaching a row both ways of one axis wears that axis's glyph, a
/// four-way one keeps today's mark, a "Gestures" row leads with its
/// action's symbol or app, and each section lays its badges and
/// chords out in columns behind a divider.
@MainActor
@Suite("Shortcuts panel gesture columns")
struct ShortcutGestureColumnsTests {
    private let keys: ScrollChord = [.control, .option]

    private func folded(_ id: String, _ luas: [String]) -> ShortcutRow {
        var row = ShortcutRow(id: id, label: id, combo: "")
        row.members = luas.map { ShortcutRow(id: $0, label: $0, combo: "") }
        return row
    }

    private func badge(
        _ bindings: [GestureKey: GestureAction],
        on row: ShortcutRow
    ) throws -> ShortcutGestureBadge {
        let built = ShortcutsReferenceBuilder.withGestures(
            ShortcutsReference(
                layerName: "default",
                controls: [ShortcutSubgroup(title: "T", rows: [row])],
                apps: [],
                custom: []
            ),
            bindings: bindings,
            name: { $0.lua }
        )
        let drawn = try #require(built.controls.first?.rows.first)
        return try #require(drawn.gestures.first)
    }

    private let spaces = [
        "KiwiDesk.focus_space_previous()", "KiwiDesk.focus_space_next()",
    ]

    @Test("both ways of one axis draw that axis")
    func twoWayDrawsTheAxis() throws {
        let horizontal = try badge(
            [
                GestureKey(.swipe3, keys): .split(
                    GestureSplit(axes: [.leftRight: .space])
                )
            ],
            on: folded("spaces", spaces)
        )
        #expect(horizontal.direction == nil)
        #expect(horizontal.axis == .horizontal)
        #expect(
            horizontal.symbol
                == CustomGlyph.swipeAxis(3, vertical: false).name
        )
        let vertical = try badge(
            [
                GestureKey(.swipe2, keys): .split(
                    GestureSplit(axes: [.upDown: .space])
                )
            ],
            on: folded("spaces", spaces)
        )
        #expect(vertical.axis == .vertical)
        #expect(
            vertical.symbol == CustomGlyph.swipeAxis(2, vertical: true).name
        )
    }

    @Test("a four-way family keeps today's mark")
    func fourWayKeepsTheMark() throws {
        let ways = ["left", "down", "up", "right"]
        let four = try badge(
            [GestureKey(.swipe3, keys): .family(.focus)],
            on: folded("focus", ways.map { "KiwiDesk.focus(\"\($0)\")" })
        )
        #expect(four.axis == nil)
        #expect(four.symbol == GestureListWords.symbol(.swipe3))
    }

    @Test("only an exact axis pair is an axis")
    func axisIsExact() {
        typealias Axis = ShortcutGestureBadge.Axis
        #expect(Axis.of([.left, .right]) == .horizontal)
        #expect(Axis.of([.up, .down]) == .vertical)
        #expect(Axis.of([.left, .up]) == nil)
        #expect(Axis.of([.left, .right, .up]) == nil)
        #expect(Axis.of([.left]) == nil)
    }

    @Test("each axis glyph resolves by its name")
    func axisGlyphsResolve() {
        for n in 2...4 {
            for vertical in [false, true] {
                let glyph = CustomGlyph.swipeAxis(n, vertical: vertical)
                #expect(CustomGlyph(name: glyph.name) == glyph)
            }
        }
    }

    @Test("a Gestures row leads with its action's mark")
    func gestureRowsLead() throws {
        let app = KeybindingCatalog.appCommand(
            "com.apple.safari",
            action: .openOrFocus
        )
        let built = ShortcutsReferenceBuilder.withGestures(
            ShortcutsReference(
                layerName: "default",
                controls: [],
                apps: [],
                custom: []
            ),
            bindings: [
                GestureKey(.drag, [.control, .command]): .grab(.move),
                GestureKey(.tap3): .run(LuaAction(lua: "print(1)")),
                GestureKey(.tap4): .run(
                    LuaAction(lua: app, kind: .application)
                ),
                GestureKey(.tap5): .run(
                    LuaAction(
                        lua: "KiwiDesk.reload_config()",
                        kind: .navigation
                    )
                ),
                GestureKey(.swipe4, keys): .family(.space),
            ],
            name: { $0.lua },
            icon: { _ in .symbol("arrow.clockwise") }
        )
        let rows = try #require(built.groups.last?.rows)
        func row(_ input: GestureInput) throws -> ShortcutRow {
            try #require(rows.first { $0.gestures.first?.key.input == input })
        }
        #expect(
            try row(.drag).icon
                == .symbol(ShortcutsReferenceBuilder.grabIcon(.move))
        )
        #expect(try row(.tap3).icon == .symbol(LuaMark.symbol))
        #expect(try row(.tap4).bundleID == "com.apple.safari")
        #expect(try row(.tap4).icon == nil)
        #expect(try row(.tap5).icon == .symbol("arrow.clockwise"))
        #expect(
            try row(.swipe4).icon
                == .symbol(ShortcutsReferenceBuilder.familyIcon(for: .space))
        )
    }

    /// The layout is SwiftUI's to draw, so the wiring is read from
    /// the source: the section hands its rows the columns, a row
    /// draws the divider only beside a gesture and keeps its slot
    /// otherwise, and the chord takes the section's width.
    @Test("a section lays out its badges and chords in columns")
    func columnsAreWired() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Shortcuts")
        func flat(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: dir.appendingPathComponent(file)
            ).filter { !$0.isWhitespace }
        }
        let sheet = try flat("ShortcutsSheetView.swift")
        #expect(
            sheet.contains(
                ".modifier(ShortcutSectionColumns(badges:section.rows"
                    + ".contains{!$0.gestures.isEmpty}))"
            )
        )
        let row = try flat("ShortcutsBands.swift")
        #expect(
            row.contains(
                "ifcolumns.badges{ShortcutGestureBadgeView(badges:"
                    + "row.gestures)Group{if!row.gestures.isEmpty{"
                    + "PanelDivider(axis:.vertical,"
            )
        )
        #expect(row.contains(".frame(width:ShortcutColumns.dividerSlot)"))
        #expect(
            row.contains(
                "key:ShortcutChordWidthKey.self,value:proxy.size.width"
            )
        )
        #expect(
            row.contains(
                ".frame(minWidth:columns?.chord??0,alignment:.trailing)"
            )
        )
        #expect(row.contains("gestureColumnchord}"))
        let columns = try flat("ShortcutColumns.swift")
        #expect(
            columns.contains(
                ".onPreferenceChange(ShortcutChordWidthKey.self){chord=$0}"
            )
        )
    }
}
