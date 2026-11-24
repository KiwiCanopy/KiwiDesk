import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side's derived sizes (#3164, #3570 ruling 4): one
/// column per screen, its Desktops stacked; the line height from 36
/// down to 30 pt fitting the tallest column under the cap; the
/// columns sharing the panel's width over a 224 pt floor, and the
/// side asking one narrowest column per screen; icons at the line
/// less 8 and slots following the width; and the state and the side
/// reading one answer. Main actor for `JumpPanelView.width`; pure
/// arithmetic, no AppKit.
@Suite("Desktops side geometry (#3164, #3570)")
@MainActor
struct DesktopsGeometryTests {
    typealias G = DesktopsGeometry
    typealias T = DesktopsStateTests
    static let cap = T.cap

    /// `desktops` Desktops of `spaces` Space lines each.
    static func screen(
        _ id: UInt32,
        desktops: Int,
        spaces: Int
    ) -> DesktopOverview.Screen {
        DesktopOverview.Screen(
            display: DisplayID(id),
            name: "Screen \(id)",
            isMain: id == 1,
            isHere: id == 1,
            desktops: (1...desktops).map { label in
                T.desktop(
                    label,
                    shown: label == 1,
                    (1...spaces).map { T.line("\($0)", [], shown: $0 == 1) }
                )
            }
        )
    }

    /// An area group over `lines` of a split screen's Desktop.
    static func area(
        _ id: Int,
        lines: Range<Int>,
        here: Bool = false
    ) -> DesktopOverview.Area {
        DesktopOverview.Area(
            key: ScreenAreaKey(fingerprint: "Wide:3440x1440", areaID: id),
            name: nil,
            position: id == 0 ? .left : .right,
            isHere: here,
            lines: lines
        )
    }

    static func geometry(
        _ screens: [DesktopOverview.Screen],
        width: CGFloat = JumpPanelView.width,
        cap: CGFloat = cap
    ) -> G {
        G(
            overview: DesktopOverview(screens: screens, yours: nil),
            width: width,
            cap: cap
        )
    }

    @Test("the line is the tallest from 36 to 30 pt that fits")
    func lineHeight() {
        let one = Self.geometry([Self.screen(1, desktops: 1, spaces: 4)])
        #expect(one.line == G.tallestLine)
        // Three Desktops of three lines stacked in one column: the
        // budget less three titles and two gaps, over nine lines.
        let screens = [
            Self.screen(1, desktops: 3, spaces: 3),
            Self.screen(2, desktops: 1, spaces: 2),
        ]
        let two = Self.geometry(screens)
        let budget = Self.cap - G.chrome
        let fixed = 3 * (G.titleHeight + G.titleGap) + 2 * G.desktopGap
        let fit = ((budget - fixed) / 9).rounded(.down)
        #expect(fit < G.tallestLine && fit > G.shortestLine)
        #expect(two.line == fit)
        #expect(two.stacks[0] == fixed + 9 * fit)
        #expect(two.stacks[1] == G.titleHeight + G.titleGap + 2 * fit)
        #expect(two.height == G.chrome + two.stacks[0])
        #expect(two.height <= Self.cap)
        #expect(
            Self.geometry(screens, cap: two.height - 1).line < fit
        )
    }

    @Test("below 30 pt the column scrolls down")
    func scrollsBelowTheFloor() {
        let deep = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 12),
            Self.screen(2, desktops: 1, spaces: 1),
        ])
        #expect(deep.line == G.shortestLine)
        #expect(deep.height == Self.cap)
        #expect(deep.body == Self.cap - G.chrome)
        #expect(deep.stacks[0] > deep.body)
        // More screens never shorten the line: they add columns.
        let five = Self.geometry(
            (1...5).map { Self.screen($0, desktops: 1, spaces: 4) }
        )
        #expect(five.line == G.tallestLine)
    }

    @Test("an area adds its header and gap to its Desktop (#3572)")
    func areasCountTheirHeaders() {
        let plain = T.desktop(
            1,
            shown: true,
            [T.line("1", []), T.line("2", [])]
        )
        let split = DesktopOverview.Desktop(
            native: 1,
            label: 1,
            number: 1,
            isShown: true,
            profile: nil,
            spaces: plain.spaces,
            areas: [
                Self.area(0, lines: 0..<1),
                Self.area(1, lines: 1..<2),
            ]
        )
        let header = G.areaHeight + G.areaGap
        #expect(
            G.card(of: split, line: 30) == G.card(of: plain, line: 30)
                + 2 * header
        )
        #expect(G.areaHeight == 16)
    }

    @Test("one column per screen, sharing the width over 224 pt")
    func columnsFillTheWidth() {
        let room = JumpPanelView.width - 2 * G.rowInset
        #expect(room == 688)
        let two = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 2),
            Self.screen(2, desktops: 5, spaces: 2),
        ])
        let half = ((room - G.divider) / 2).rounded(.down)
        #expect(two.columns == [half, half])
        // Four screens outgrow the panel: every column at the floor,
        // so the row of screens scrolls sideways.
        let four = Self.geometry(
            (1...4).map { Self.screen($0, desktops: 2, spaces: 2) }
        )
        #expect(four.columns == Array(repeating: G.narrowestColumn, count: 4))
        let drawn = four.columns.reduce(0, +) + 3 * G.divider
        #expect(drawn > room)
    }

    @Test("the side asks one narrowest column per screen")
    func preferredWidth() {
        func asked(_ count: UInt32) -> CGFloat {
            G.preferredWidth(
                of: DesktopOverview(
                    screens: (1...count).map {
                        Self.screen($0, desktops: 1, spaces: 1)
                    },
                    yours: nil
                )
            )
        }
        #expect(asked(1) == 2 * G.rowInset + G.narrowestColumn)
        // Each screen adds a column and its divider, whatever its
        // Desktops.
        #expect(asked(4) - asked(3) == G.narrowestColumn + G.divider)
        // Granted, the columns stand at the floor exactly.
        let overview = DesktopOverview(
            screens: (1...5).map { Self.screen($0, desktops: 3, spaces: 2) },
            yours: nil
        )
        let granted = G(
            overview: overview,
            width: G.preferredWidth(of: overview),
            cap: Self.cap
        )
        #expect(granted.columns.allSatisfy { $0 == G.narrowestColumn })
    }

    @Test("icons follow the line; slots follow the width")
    func iconsAndSlots() {
        let g = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 2),
            Self.screen(2, desktops: 2, spaces: 2),
        ])
        #expect(g.line == 36)
        #expect(g.icon == 28)
        let short = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 12),
            Self.screen(2, desktops: 1, spaces: 8),
        ])
        #expect(short.icon == 22)
        // The floor of 22 holds by construction at the shortest line.
        #expect(G.shortestLine - 8 == 22)
        #expect(g.slots.count == 2)
        #expect(g.slots.allSatisfy { $0 >= 1 })
        // At 28 pt icons: two 343 pt columns, four at 224 pt.
        #expect(g.slots == [7, 7])
        let four = Self.geometry(
            (1...4).map { Self.screen($0, desktops: 1, spaces: 2) }
        )
        #expect(four.slots == [3, 3, 3, 3])
    }

    @Test("a line's slots are its screen's")
    func stateTakesTheSlots() throws {
        let overview = T.overview()
        let state = T.state(overview)
        let place = try #require(state.place)
        #expect(place.screen == 1)
        let slots = state.geometry.slots
        #expect(slots[1] == 5)
        #expect(slots[0] == slots[1])
        #expect(state.slots(place) == slots[1])
        // Seven windows on the line, five shown: two after.
        #expect(state.hidden(place).after == 2)
        let other = DesktopsPlace(screen: 0, desktop: 0, line: 0)
        #expect(state.slots(other) == slots[0])
    }

    @Test("reveals and +n step by the line's own slots")
    func keysStepBySlots() throws {
        // 640 pt: six slots on the KiwiHub screen's seven-window line.
        let overview = T.overview()
        let geometry = G(overview: overview, width: 640, cap: Self.cap)
        let fresh = DesktopsState(overview: overview, geometry: geometry)
        let place = try #require(fresh.place)
        #expect(fresh.slots(place) == 6)
        let windows = fresh.ordered(place)
        // The seventh window revealed: one slot scrolled, not two.
        var state = fresh
        state.select(window: windows[6].id, in: place)
        #expect(state.offset(place) == 1)
        #expect(state.hidden(place).before == 1)
        #expect(state.hidden(place).after == 0)
        // "+n" forward opens the window just past six slots.
        var more = fresh
        more.revealMore(place, forward: true)
        #expect(more.window == windows[6].id)
        #expect(more.offset(place) == 1)
        // 540 pt: four slots, so a reveal or a clamp by a fixed five
        // lands one slot off.
        let narrow = DesktopsState(
            overview: overview,
            geometry: G(overview: overview, width: 540, cap: Self.cap)
        )
        #expect(narrow.slots(place) == 4)
        var fifth = narrow
        fifth.select(window: windows[4].id, in: place)
        #expect(fifth.offset(place) == 1)
        var last = narrow
        last.select(window: windows[6].id, in: place)
        #expect(last.offset(place) == 3)
    }

    @Test("one geometry, from the panel's width, reaches the side")
    func widthIsWired() throws {
        let jump = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Sources/KiwiDesk/Jump")
        func read(_ name: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: jump.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
        }
        // The side draws the state's geometry, never one of its own.
        let side = try read("DesktopsSideView.swift")
            .replacingOccurrences(of: " ", with: "")
        #expect(side.contains("geometry:DesktopsGeometry{state.geometry}"))
        // One construction in the whole GUI tree: the model's.
        let gui = jump.deletingLastPathComponent()
        let walker = try #require(
            FileManager.default.enumerator(atPath: gui.path)
        )
        let files = walker.compactMap { $0 as? String }
            .filter { $0.hasSuffix(".swift") }
        #expect(files.count > 100)
        var built: [String: Int] = [:]
        for path in files {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: gui.appendingPathComponent(path),
                    encoding: .utf8
                )
            )
            let count = source.occurrences(of: "DesktopsGeometry(")
            if count > 0 { built[path] = count }
        }
        #expect(built == ["Jump/JumpModel+Desktops.swift": 1])
        let controller = try read("JumpPanelController.swift")
            .replacingOccurrences(of: " ", with: "")
        #expect(controller.contains("room:room,"))
        let model = try read("JumpModel+Desktops.swift")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        let wiring = [
            "letgutter=DesktopsGeometry.gutter(of:overview)",
            "letwidth=room.width(JumpPanelRoom.fit(of:.desktops),",
            "content:DesktopsGeometry.preferredWidth(",
            "of:overview,gutter:gutter))",
            "letgeometry=DesktopsGeometry(",
            "overview:overview,width:width,cap:sheetCap,",
            "gutter:gutter)",
        ].joined()
        #expect(model.contains(wiring))
        #expect(model.contains("geometry:geometry)"))
    }
}
