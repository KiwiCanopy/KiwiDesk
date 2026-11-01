import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Remove from Pocket in the bar menus' float slot (#2612 ▸ 4):
/// enabled for a window `toggle_pocket_window` marked, acting
/// through that verb naming it; greyed with its subtitle for a
/// window its app's Pocket key keeps, as Pocket Window is (▸ 11).
@Suite("Pocket ▸ Remove from Pocket row", .serialized)
@MainActor
struct PocketRemoveRowTests {
    private typealias Fixture = PocketAppFixture
    private let mine = WindowID(9)
    private let other = WindowID(1)

    private func row(
        _ title: String,
        of id: WindowID,
        in core: KiwiCore
    ) -> BarMenuRow? {
        core.barMenuRows(.appItem([id])).first { $0.title == title }
    }

    private func perform(_ row: BarMenuRow?) {
        guard case .action(let perform)? = row?.kind else {
            Issue.record("not an action")
            return
        }
        perform()
    }

    private func keyedFixture() -> Fixture {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        #expect(fixture.owner(of: mine) == Fixture.app)
        return fixture
    }

    @Test("toggle_pocket_window names its window, not the focus")
    func verbNamesItsWindow() {
        LocalizationManager.shared.select("en")
        let fixture = keyedFixture()
        let core = fixture.core
        core.state.apply(.windowFocused(mine))
        let response = core.execute(
            "toggle_pocket_window",
            args: [.number(Double(other.raw))]
        )
        #expect(response.isSuccess)
        #expect(core.state.pocketPhase(of: other) == .out)
        #expect(core.state.pocketKeyOwner(of: other) == nil)
    }

    @Test("an id no window carries is refused")
    func unknownIDRefuses() {
        let core = Fixture(row: false).core
        let response = core.execute(
            "toggle_pocket_window",
            args: [.number(77)]
        )
        #expect(response.error == "unknown window: 77")
        #expect(core.state.pocket.isEmpty)
    }

    @Test("a marked window's menu offers Remove, then Pocket Window")
    func markedWindowRows() {
        LocalizationManager.shared.select("en")
        let core = Fixture(row: false).core
        core.execute("toggle_pocket_window", args: [.number(1)])
        let titles = core.barMenuRows(.appItem([other])).map(\.title)
        let remove = titles.firstIndex(of: "Remove from Pocket")
        let pocket = titles.firstIndex(of: "Pocket Window")
        #expect(remove != nil && pocket == remove.map { $0 + 1 })
        #expect(!titles.contains("Tile Window"))
        let row = row("Remove from Pocket", of: other, in: core)
        #expect(row?.enabled == true)
        #expect(row?.subtitle == nil)
        perform(row)
        #expect(core.state.pocketPhase(of: other) == nil)
    }

    @Test("an unmarked window keeps its float row")
    func unmarkedKeepsFloatRow() {
        LocalizationManager.shared.select("en")
        let core = Fixture(row: false).core
        let titles = core.barMenuRows(.appItem([other])).map(\.title)
        #expect(titles.contains("Float Window"))
        #expect(!titles.contains("Remove from Pocket"))
    }

    @Test("a keyed window greys Remove and Pocket Window")
    func keyedWindowGreys() {
        LocalizationManager.shared.select("en")
        let fixture = keyedFixture()
        let core = fixture.core
        let remove = row("Remove from Pocket", of: mine, in: core)
        #expect(remove?.enabled == false)
        #expect(remove?.subtitle == KiwiCore.pocketKeyKeepsIt)
        #expect(remove?.subtitle?.hasPrefix("Its Pocket key") == true)
        #expect(row("Pocket Window", of: mine, in: core)?.enabled == false)
        let response = core.execute(
            "toggle_pocket_window",
            args: [.number(Double(mine.raw))]
        )
        #expect(response.error == "this window has a Pocket key of its own")
        #expect(fixture.owner(of: mine) == Fixture.app)
    }
}
