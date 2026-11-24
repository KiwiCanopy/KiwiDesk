import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shared-Desktop grid's sizes (#3602): a header column 96–132
/// pt wide from the widest title, rows as tall as their header or
/// tallest cell, the rows summed under the cap, and the side asking
/// the header column and its gap besides the screens. Pure
/// arithmetic with an injected title measure, no AppKit; main
/// actor for the titles' localized text.
@Suite("Desktops shared-Desktop grid geometry (#3602)")
@MainActor
struct DesktopsGridGeometryTests {
    typealias G = DesktopsGeometry
    typealias F = DesktopsGridFixture

    @Test("an overview without rows draws no grid")
    func noGridWithoutRows() {
        #expect(F.geometry(F.overview(shared: false)).grid == nil)
        #expect(G.gutter(of: F.overview(shared: false)) == nil)
        #expect(F.geometry().grid != nil)
    }

    @Test("the header column follows the widest title, held to 96–132")
    func gutterClamps() {
        let narrow = F.geometry(measure: { _ in 10 })
        #expect(narrow.grid?.gutter == G.narrowestGutter)
        let wide = F.geometry(measure: { _ in 400 })
        #expect(wide.grid?.gutter == G.widestGutter)
        let mid = F.geometry(measure: { _ in 90 })
        #expect(
            mid.grid?.gutter
                == 90 + G.checkSlot + G.headerLeading + G.headerTrailing
        )
    }

    @Test("the header column and a row's header read the row's facts")
    func headerReadsTheRow() throws {
        LocalizationManager.shared.select("en")
        // Rows naming Desktop 10 and a profile the columns' cards
        // lack: the gutter measures "Desktop 10", and row 1's header
        // grows a profile line its cells' cards do not carry.
        let rows = [
            F.row(10, profile: nil, shown: true),
            F.row(2, profile: "Home", shown: false),
        ]
        var overview = F.overview(rows: rows)
        let gutter = try #require(G.gutter(of: overview, measure: F.measure))
        let title = F.measure(DesktopsText.desktop(10))
        #expect(
            gutter
                == max(
                    title + G.checkSlot + G.headerLeading + G.headerTrailing,
                    G.narrowestGutter
                )
        )
        // One line per cell, so a header with a profile outgrows it.
        overview = DesktopOverview(
            screens: overview.screens.map { screen in
                DesktopOverview.Screen(
                    display: screen.display,
                    name: screen.name,
                    isMain: screen.isMain,
                    isHere: screen.isHere,
                    desktops: screen.desktops.map {
                        F.desktop($0.label, lines: 1)
                    }
                )
            },
            yours: nil,
            rows: rows
        )
        let line = G.tallestLine
        #expect(
            G.row(1, of: overview, line: line)
                == G.header(line: line, profile: true) + 2 * G.rowPadding
        )
        #expect(
            G.row(0, of: overview, line: line) == line + 2 * G.rowPadding
        )
    }

    @Test("a row is its header or its tallest cell, padded")
    func rowHeights() throws {
        let geometry = F.geometry()
        let grid = try #require(geometry.grid)
        let line = geometry.line
        #expect(line == G.tallestLine)
        let area = G.areaHeight + G.areaGap
        // Desktop 1: Built-in's split cell (two areas, four lines)
        // outgrows DELL's three lines and the header.
        #expect(grid.rows[0] == 2 * area + 4 * line + 2 * G.rowPadding)
        // Desktop 2: DELL's two lines against a header with a
        // profile line under the title.
        let header = G.header(line: line, profile: true)
        #expect(grid.rows[1] == max(header, 2 * line) + 2 * G.rowPadding)
        #expect(
            geometry.height
                == G.chrome + grid.rows[0] + grid.rows[1] + G.divider
        )
    }

    @Test("the line is the tallest at which every row fits the cap")
    func lineFitsRows() throws {
        let overview = F.overview()
        let tall = G.rows(of: overview, line: G.tallestLine)
        // Room for the rows a few points under the tallest line.
        let cap = G.chrome + tall.reduce(0, +) + G.divider - 8
        let geometry = F.geometry(cap: cap)
        #expect(geometry.line < G.tallestLine)
        #expect(geometry.line >= G.shortestLine)
        let grid = try #require(geometry.grid)
        #expect(G.chrome + grid.height <= cap)
        let taller = G.rows(of: overview, line: geometry.line + 1)
        #expect(
            G.chrome + G.Grid(gutter: 0, rows: taller).height > cap
        )
    }

    @Test("the side asks the header column and its gap besides")
    func preferredWidth() {
        let gutter = F.geometry().grid?.gutter ?? 0
        let shared = G.preferredWidth(of: F.overview(), gutter: gutter)
        let columns = G.preferredWidth(
            of: F.overview(shared: false),
            gutter: gutter
        )
        #expect(shared == columns + gutter + G.gutterGap)
        #expect(F.geometry().preferred == shared)
        #expect(
            columns
                == G.preferredWidth(
                    of: F.overview(shared: false),
                    gutter: nil
                )
        )
    }

    @Test("the columns share what the header column leaves")
    func columnsShareTheRest() {
        let gutter = F.geometry().grid?.gutter ?? 0
        let width: CGFloat = 1000
        let room = width - 2 * G.rowInset - gutter - G.gutterGap
        #expect(
            F.geometry(width: width).columns
                == G.columns(count: 2, room: room)
        )
    }

    @Test("a line's top counts the area headers above it")
    func lineTop() {
        let desktop = F.overview().screens[0].desktops[0]
        let area = G.areaHeight + G.areaGap
        #expect(G.lineTop(of: desktop, at: 0, line: 30) == area)
        #expect(G.lineTop(of: desktop, at: 2, line: 30) == 2 * area + 60)
    }
}
