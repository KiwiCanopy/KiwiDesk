import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shortcuts panel's gesture column (#3380 ▸ Ruling): a family
/// reaching a row both ways of one axis wears that axis's glyph, a
/// four-way one keeps today's mark, a "Gestures" row leads with its
/// action's symbol or app, and each section lays its badges and
/// chords out in columns behind a divider. Spend: a few builder
/// runs and three small source reads on the main actor, which the
/// `L()` wording and `CustomGlyph` images need.
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
            command: { _ in nil }
        )
        let drawn = try #require(built.controls.first?.rows.first)
        return try #require(drawn.gestures.first)
    }

    private static let reload = NavCommand(
        label: "Reload",
        lua: "KiwiDesk.reload_config()",
        icon: "arrow.clockwise"
    )

    private static let starred: KeyBindingMeta = {
        var meta = KeyBindingMeta.none
        meta.symbol = "star"
        return meta
    }()

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

    @Test("an axis badge names both of its ways")
    func axisIsWorded() throws {
        LocalizationManager.shared.select("en")
        let key = GestureKey(.swipe3, keys)
        let horizontal = ShortcutGestureBadge(
            key: key,
            direction: nil,
            axis: .horizontal
        )
        #expect(horizontal.words.hasSuffix("Left or right"))
        #expect(horizontal.spoken.contains("Left or right"))
        let vertical = ShortcutGestureBadge(
            key: key,
            direction: nil,
            axis: .vertical
        )
        #expect(vertical.words.hasSuffix("Up or down"))
        // A direction keeps its one way, and the axis is dropped.
        let way = ShortcutGestureBadge(
            key: key,
            direction: .left,
            axis: .horizontal
        )
        #expect(way.axis == nil)
        #expect(way.words.hasSuffix("Left"))
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
                GestureKey(.tap2): .run(LuaAction(lua: Self.reload.lua)),
                GestureKey(.tap2, keys): .run(
                    LuaAction(
                        lua: Self.reload.lua,
                        kind: .navigation,
                        meta: Self.starred
                    )
                ),
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
            command: { $0.lua == Self.reload.lua ? Self.reload : nil }
        )
        let rows = try #require(built.groups.last?.rows)
        func row(
            _ input: GestureInput,
            _ chord: ScrollChord = []
        ) throws -> ShortcutRow {
            let key = GestureKey(input, chord)
            return try #require(rows.first { $0.gestures.first?.key == key })
        }
        #expect(
            try row(.drag, [.control, .command]).icon
                == .symbol(ShortcutsReferenceBuilder.grabIcon(.move))
        )
        #expect(try row(.tap3).icon == .symbol(LuaMark.symbol))
        #expect(try row(.tap4).bundleID == "com.apple.safari")
        #expect(try row(.tap4).icon == nil)
        let reloadIcon = ShortcutsReferenceBuilder.icon(for: Self.reload)
        #expect(try row(.tap5).icon == reloadIcon)
        #expect(try row(.tap5).label == "Reload")
        // The user's own Lua is never a catalogue command, even when
        // it spells one (architect review).
        // A binding's own symbol leads ahead of the catalogue's
        // (guard-prover).
        #expect(try row(.tap2, keys).icon == .symbol("star"))
        #expect(try row(.tap2).label == Self.reload.lua)
        #expect(try row(.tap2).icon == .symbol(LuaMark.symbol))
        #expect(
            try row(.swipe4, keys).icon
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
                    + ".contains{!$0.gestures.isEmpty},chords:section.rows"
                    + ".contains{!$0.combo.isEmpty}))"
            )
        )
        let row = try flat("ShortcutsBands.swift")
        #expect(
            row.contains(
                "ifcolumns.badges{ShortcutGestureBadgeView(badges:"
                    + "row.gestures)ifcolumns.chords{dividerSlot}}"
            )
        )
        // The slot is kept on a row with no gesture; the divider is
        // drawn only beside one.
        #expect(
            row.contains(
                "ZStack{Color.clearif!row.gestures.isEmpty{"
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
