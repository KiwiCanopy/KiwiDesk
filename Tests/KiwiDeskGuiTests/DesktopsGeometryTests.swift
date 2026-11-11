import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side's derived sizes (#3164 ▸ Ruling and
/// amendment): the line height from 36 down to 30 pt fitting every
/// screen row under the cap, columns sharing each row's width over
/// a 224 pt floor, icons at the line less 8 and slots following the
/// width; and the state and the side reading one answer. Main
/// actor for `JumpPanelView.width`; pure arithmetic, no AppKit.
@Suite("Desktops side geometry (#3164)")
@MainActor
struct DesktopsGeometryTests {
    typealias G = DesktopsGeometry
    typealias T = DesktopsStateTests
    static let cap: CGFloat = 411

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
        // Two screens, four Spaces deep: each row's share of the cap
        // over four lines, rounded down, inside 30...36.
        let two = Self.geometry([
            Self.screen(1, desktops: 2, spaces: 4),
            Self.screen(2, desktops: 1, spaces: 2),
        ])
        let share = (Self.cap - G.chrome(rows: 2)) / 2
        let fit = (share / 4).rounded(.down)
        #expect(fit < G.tallestLine && fit > G.shortestLine)
        #expect(two.line == fit)
        #expect(two.lines == [4 * fit, 2 * fit])
        #expect(two.height <= Self.cap)
        #expect(
            Self.geometry(
                [
                    Self.screen(1, desktops: 2, spaces: 4),
                    Self.screen(2, desktops: 1, spaces: 2),
                ],
                cap: two.height - 1
            ).line < 35
        )
    }

    @Test("below 30 pt the column scrolls; past two screens the side")
    func scrollsBelowTheFloor() {
        let deep = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 8),
            Self.screen(2, desktops: 1, spaces: 1),
        ])
        #expect(deep.line == G.shortestLine)
        #expect(deep.lines[0] < 8 * G.shortestLine)
        #expect(deep.lines[1] == G.shortestLine)
        #expect(deep.height <= Self.cap)
        // A third screen sizes lines as two do, and the side scrolls.
        let three = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 4),
            Self.screen(2, desktops: 1, spaces: 4),
            Self.screen(3, desktops: 1, spaces: 4),
        ])
        let two = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 4),
            Self.screen(2, desktops: 1, spaces: 4),
        ])
        #expect(three.line == two.line)
        #expect(three.height == Self.cap)
    }

    @Test("columns share each row's width, never under 224 pt")
    func columnsFillTheRow() {
        let g = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 2),
            Self.screen(2, desktops: 2, spaces: 2),
            Self.screen(3, desktops: 3, spaces: 2),
            Self.screen(4, desktops: 5, spaces: 2),
        ])
        let room = JumpPanelView.width - 2 * G.rowInset
        #expect(room == 688)
        #expect(g.columns == [688, 343, 228, G.narrowestColumn])
        // A narrower panel shares its own width.
        let narrow = Self.geometry(
            [Self.screen(1, desktops: 2, spaces: 2)],
            width: 600
        )
        let share = (600 - 2 * G.rowInset - G.divider) / 2
        #expect(narrow.columns == [share.rounded(.down)])
    }

    @Test("icons follow the line; slots follow the width")
    func iconsAndSlots() {
        let g = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 2),
            Self.screen(2, desktops: 4, spaces: 2),
        ])
        #expect(g.line == 36)
        #expect(g.icon == 28)
        let short = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 8),
            Self.screen(2, desktops: 1, spaces: 8),
        ])
        #expect(short.icon == 22)
        // The floor of 22 holds by construction at the shortest line.
        #expect(G.shortestLine - 8 == 22)
        #expect(g.slots.count == 2)
        #expect(g.slots[0] > g.slots[1])
        #expect(g.slots.allSatisfy { $0 >= 1 })
        // At 28 pt icons: 688, 343, 228 and 224 pt columns.
        let rows = Self.geometry([
            Self.screen(1, desktops: 1, spaces: 2),
            Self.screen(2, desktops: 2, spaces: 2),
            Self.screen(3, desktops: 3, spaces: 2),
            Self.screen(4, desktops: 5, spaces: 2),
        ])
        #expect(rows.icon == 28)
        #expect(rows.slots == [19, 7, 3, 3])
    }

    @Test("a line's slots are its screen's")
    func stateTakesTheSlots() throws {
        let overview = T.overview()
        let state = T.state(overview)
        let place = try #require(state.place)
        #expect(place.screen == 1)
        let slots = state.geometry.slots
        #expect(slots[1] == 5)
        #expect(slots[0] > slots[1])
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
    }

    @Test("the model hands the state the side's slots")
    func modelWiresTheSlots() {
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 9,
            sheetCap: Self.cap,
            panelWidth: 600
        )
        model.loadDesktops = { T.overview() }
        model.setScope(.desktops)
        let expected = G(
            overview: T.overview(),
            width: 600,
            cap: Self.cap
        ).slots
        #expect(model.desktops?.geometry.slots == expected)
        #expect(
            expected
                != G(
                    overview: T.overview(),
                    width: JumpPanelView.width,
                    cap: Self.cap
                ).slots
        )
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
        #expect(side.occurrences(of: "DesktopsGeometry(") == 0)
        let controller = try read("JumpPanelController.swift")
            .replacingOccurrences(of: " ", with: "")
        #expect(controller.contains("panelWidth:width,"))
        let model = try read("JumpModel+Desktops.swift")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(model.contains("width:panelWidth,cap:sheetCap"))
        #expect(model.contains("geometry:geometry)"))
    }
}
