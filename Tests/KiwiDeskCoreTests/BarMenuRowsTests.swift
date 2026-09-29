import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-bar-menus-\(UUID().uuidString)")
    )
}

/// What each right-click shows (#1518, the owner's 2026-09-28
/// ruling): a hit's rows above the shelf section, which ends every
/// menu; a Space chip's Layout menu sets that Space, a `+N` sets
/// the span in the live profile and hands the edit to an open
/// draft, and every Settings row asks the GUI for its landing.
@Suite("Bar menu rows, built", .serialized)
@MainActor
struct BarMenuRowsTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    private func seededCore() -> KiwiCore {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(one)
        return core
    }

    private func titles(_ rows: [BarMenuRow]) -> [String] {
        rows.map { $0.isSeparator ? "—" : $0.title }
    }

    private func submenu(_ row: BarMenuRow) throws -> [BarMenuRow] {
        guard case .submenu(let rows) = row.kind else {
            Issue.record("\(row.title) is not a submenu")
            return []
        }
        return rows
    }

    private func perform(_ row: BarMenuRow) {
        guard case .action(let perform) = row.kind else {
            Issue.record("\(row.title) is not an action")
            return
        }
        perform()
    }

    private let shelf = [
        "KiwiShelf Settings…", "Looks…", "Advanced Colors…",
    ]

    @Test("every menu ends with the shelf section")
    func shelfSectionEndsEveryMenu() {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        #expect(titles(core.barMenuRows(.empty)) == shelf)
        #expect(titles(core.barMenuRows(.count)) == shelf)
        for hit in [BarHit.space(one), .disc(one), .divider] {
            let rows = titles(core.barMenuRows(hit))
            #expect(Array(rows.suffix(4)) == ["—"] + shelf, "\(hit)")
        }
    }

    @Test("the shelf rows land where their names say")
    func shelfRowsLand() {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        var landed: [SettingsLanding] = []
        core.barMenuHooks.openSettings = { landed.append($0) }
        core.barMenuRows(.empty).forEach(perform)
        #expect(landed == [.shelf, .looks, .advancedColors])
        let chip = core.barMenuRows(.space(two))
        perform(chip[1])
        #expect(landed.last == .space(two))
    }

    /// A Space chip's Layout menu is the status item's rows, and a
    /// row sets THAT Space, shown or not.
    @Test("a chip's Layout menu sets its own Space")
    func chipLayoutSetsItsSpace() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        let chip = core.barMenuRows(.space(two))
        #expect(titles(chip).prefix(2) == ["Layout", "Space Settings…"])
        let layout = try submenu(chip[0])
        #expect(layout.count == LayoutMode.allCases.count)
        let live = try #require(core.state.workspaces[two]?.mode)
        #expect(
            layout.filter(\.checked).map(\.title)
                == [LayoutModeRows.coreWords.name(live)]
        )
        let grid = try #require(layout.first { $0.title == "Grid" })
        perform(grid)
        #expect(core.state.workspaces[two]?.mode == .grid)
        #expect(core.state.workspaces[one]?.mode == live)
    }

    /// With a live profile the Layout menu keeps its Keep row,
    /// greyed until a Space differs from what the profile saved.
    @Test("the Keep row arms on a temporary layout")
    func keepRowArms() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        try core.persistProfile(named: "Desk", modes: nil)
        #expect(core.profiles.currentName == "Desk")
        let keep = { () throws -> BarMenuRow in
            let layout = try self.submenu(core.barMenuRows(.space(one))[0])
            return try #require(layout.last)
        }
        #expect(try keep().title == "Keep Layout in Profile “Desk”")
        #expect(try keep().enabled == false)
        let current = try #require(core.state.workspaces[one]?.mode)
        let other: LayoutMode = current == .grid ? .stack : .grid
        core.execute(
            "set_mode",
            args: [.string("1"), .string(other.rawValue)]
        )
        #expect(try keep().enabled)
        var kept = 0
        core.barMenuHooks.keepLayout = { kept += 1 }
        perform(try keep())
        #expect(kept == 1)
    }

    /// The `+N` picker writes the live setting through its setter,
    /// the live profile's file, and hands the same edit to an open
    /// draft.
    @Test("a disc's span row writes the live profile and the draft")
    func discSetsTheSpan() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        try core.persistProfile(named: "Desk", modes: nil)
        let disc = core.barMenuRows(.disc(one))
        #expect(disc[0].title == "Glyphs per Space")
        let spans = try submenu(disc[0])
        #expect(
            spans.map(\.title)
                == SpaceBarStyle.glyphSpanRange.map { "\($0)" }
        )
        let current = core.tiler.settings.spaceBarStyle.resolvedGlyphSpan
        #expect(spans.filter(\.checked).map(\.title) == ["\(current)"])
        var draft = TilingSettings()
        core.barMenuHooks.settingsWritten = { edit in edit(&draft) }
        let pick = current == 3 ? 4 : 3
        perform(spans[pick - 1])
        #expect(core.tiler.settings.spaceBarStyle.glyphSpan == pick)
        #expect(draft.spaceBarStyle.glyphSpan == pick)
        let stored = try core.profiles.read(name: "Desk")
        #expect(stored.settings.spaceBarStyle.glyphSpan == pick)
    }

    @Test("the divider's reset is greyed at the default")
    func dividerReset() {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        let reset = { core.barMenuRows(.divider)[0] }
        #expect(reset().title == "Reset Space Bar Minimum")
        #expect(reset().enabled == false)
        core.tiler.settings.kiwishelf.minimum = KiwiShelf.resetMinimum + 10
        #expect(reset().enabled)
        perform(reset())
        #expect(
            core.tiler.settings.kiwishelf.minimum == KiwiShelf.resetMinimum
        )
    }

    @Test("the bootstrap wires one menu source to both bars")
    func bootstrapWiresTheMenus() {
        let core = seededCore()
        #expect(core.spaceBars.contextMenus === core.shelves.contextMenus)
        #expect(core.appBars.contextMenus === core.shelves.contextMenus)
        #expect(!core.shelves.contextMenus.rows(.empty).isEmpty)
    }
}
