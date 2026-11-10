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
        // Two screens of four Spaces: 35 pt fits under 411, 36 not.
        let two = Self.geometry([
            Self.screen(1, desktops: 2, spaces: 4),
            Self.screen(2, desktops: 1, spaces: 2),
        ])
        #expect(two.line == 35)
        // A typed constant: the macro types a bare `4 * 35` apart.
        let fourLines: CGFloat = 4 * 35
        #expect(two.lines == [fourLines, 2 * 35])
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
        #expect(g.slots.count == 2)
        #expect(g.slots[0] > g.slots[1])
        #expect(g.slots.allSatisfy { $0 >= 1 })
        // The slots and their "+n" fit inside the column.
        for (column, slots) in zip(g.columns, g.slots) {
            let used =
                CGFloat(slots) * (g.icon + G.iconGap) - G.iconGap
                + G.labelReserve + G.moreReserve
                + 2 * (G.columnInset + G.linePadding)
            #expect(used <= column)
        }
    }

    @Test("a line's slots are its screen's")
    func stateTakesTheSlots() {
        let overview = T.overview()
        let state = DesktopsState(overview: overview, slots: [2, 3])
        let place = try! #require(state.place)
        #expect(place.screen == 1)
        #expect(state.slots(place) == 3)
        // Seven windows on the line, three shown: four after.
        #expect(state.hidden(place).after == 4)
        let none = DesktopsState(overview: overview)
        #expect(none.slots(place) == DesktopsState.fallbackSlots)
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
        #expect(model.desktops?.slotCounts == expected)
        #expect(
            expected
                != G(
                    overview: T.overview(),
                    width: JumpPanelView.width,
                    cap: Self.cap
                ).slots
        )
    }

    @Test("the side and the controller read the panel's width")
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
        let panel = try read("JumpPanelView.swift")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(
            panel.contains(
                "icons:model.desktopIcons,width:width,maxHeight:"
            )
        )
        let controller = try read("JumpPanelController.swift")
            .replacingOccurrences(of: " ", with: "")
        #expect(controller.contains("panelWidth:width,"))
        let model = try read("JumpModel+Desktops.swift")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(model.contains("width:panelWidth,cap:sheetCap"))
        #expect(model.contains("slots:geometry.slots"))
    }
}
