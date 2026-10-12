import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Jump to window's list state (#1875 ▸ Ruling — keys): row 1 is
/// preselected, the focused window being left out of the rows by
/// Core (owner, 2026-10-12); the selection never
/// wraps; ⌘ numbers run by result across the Hidden header.
@Suite("Jump to window list")
struct JumpListTests {
    static func row(
        _ id: UInt32,
        _ app: String,
        _ title: String = "",
        space: SpaceID? = "1",
        status: JumpEntry.Status = .shown,
        hidden: Bool = false
    ) -> JumpEntry {
        JumpEntry(
            target: hidden
                ? .hiddenApp(pid_t(id)) : .window(WindowID(id)),
            pid: pid_t(id),
            app: app,
            title: title,
            space: hidden ? nil : space,
            spaceIcon: nil,
            status: status
        )
    }

    private func list(
        _ entries: [JumpEntry],
        here: SpaceID? = "1"
    ) -> JumpList {
        JumpList(
            snapshot: JumpSnapshot(
                entries: entries,
                here: here,
                hereIcon: nil
            )
        )
    }

    private var three: [JumpEntry] {
        [
            Self.row(1, "Ghostty", "~/Desktop"),
            Self.row(2, "Zen Browser", "Ghostty good points"),
            Self.row(3, "Mail", "Inbox"),
        ]
    }

    @Test("row 1 is preselected, typed or not")
    func preselection() {
        var list = list(three)
        #expect(list.selection == 0)
        list.setQuery("m")
        #expect(list.selection == 0)
        #expect(list.selected?.entry.app == "Mail")
        list.setQuery("")
        #expect(list.selection == 0)
        #expect(self.list([Self.row(1, "Mail")]).selection == 0)
        #expect(self.list([]).selection == nil)
        list.setQuery("nothing matches this")
        #expect(list.selection == nil)
        #expect(list.selected == nil)
    }

    @Test("the selection clamps at both ends, never wrapping")
    func noWrap() {
        var list = list(three)
        list.step(-1)
        list.step(-1)
        #expect(list.selection == 0)
        list.step(5)
        #expect(list.selection == 2)
        list.step(1)
        #expect(list.selection == 2)
    }

    @Test("⌘ numbers name the first nine results, by result")
    func numbering() {
        let entries = (1...11).map { Self.row(UInt32($0), "App \($0)") }
        let list = list(entries)
        #expect(JumpList.number(ofRow: 0) == 1)
        #expect(JumpList.number(ofRow: 8) == 9)
        #expect(JumpList.number(ofRow: 9) == nil)
        #expect(list.quick(0)?.entry.app == "App 1")
        #expect(list.quick(8)?.entry.app == "App 9")
        #expect(list.quick(9) == nil)
        #expect(self.list(three).quick(3) == nil)
    }

    @Test("a hidden app among the first nine takes its number")
    func hiddenRowsAreNumbered() {
        let entries = three + [Self.row(9, "Spotify", hidden: true)]
        let list = list(entries)
        #expect(list.hiddenStart == 3)
        #expect(list.quick(3)?.entry.isHiddenApp == true)
        #expect(self.list(three).hiddenStart == nil)
    }

    /// Minimized windows sit under their own header, as hidden
    /// apps do (owner eyeball, 2026-10-12); a list without either
    /// draws none.
    @Test("minimized windows and hidden apps each take a section")
    func sections() {
        let entries =
            three + [
                Self.row(7, "Notes", status: .minimized),
                Self.row(8, "Mail", status: .minimized),
                Self.row(9, "Spotify", hidden: true),
            ]
        let list = list(entries)
        #expect(list.minimizedStart == 3)
        #expect(list.section(at: 3) == .minimized)
        #expect(list.section(at: 4) == nil)
        #expect(list.section(at: 5) == .hidden)
        #expect(list.sectionCount == 2)
        #expect(self.list(three).sectionCount == 0)
    }
}
