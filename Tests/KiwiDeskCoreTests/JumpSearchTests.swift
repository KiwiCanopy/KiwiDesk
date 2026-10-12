import Foundation
import Testing

@testable import KiwiDeskCore

/// Jump to window's ranking (#1875 ▸ Ruling): app-name prefix,
/// app-name contains, title word start, title contains — each
/// tier in recency order — with hidden apps below every window.
@Suite("Jump to window search (#1875)")
struct JumpSearchTests {
    private func row(
        _ id: UInt32,
        _ app: String,
        _ title: String,
        status: JumpEntry.Status = .shown
    ) -> JumpEntry {
        JumpEntry(
            target: status == .hidden
                ? .hiddenApp(pid_t(id)) : .window(WindowID(id)),
            pid: pid_t(id),
            app: app,
            title: title,
            space: nil,
            spaceIcon: nil,
            status: status
        )
    }

    private func ids(_ matches: [JumpSearch.Match]) -> [UInt32] {
        matches.map {
            switch $0.entry.target {
            case .window(let id): id.raw
            case .hiddenApp(let pid): UInt32(pid)
            }
        }
    }

    @Test("a blank query keeps every row, in order, unmarked")
    func blankKeepsAll() {
        let rows = [row(1, "Mail", "Inbox"), row(2, "Notes", "Ideas")]
        let matches = JumpSearch.matches(rows, query: "  ")
        #expect(ids(matches) == [1, 2])
        #expect(matches.allSatisfy { $0.appRange == nil })
        #expect(matches.allSatisfy { $0.titleRange == nil })
    }

    /// The issue's own example, in recency order Zen first.
    @Test("“ghost”: the app's windows, then the title match")
    func rulingExample() {
        let rows = [
            row(1, "Zen Browser", "Ghostty good points"),
            row(2, "Ghostty", "~/Desktop"),
            row(3, "Ghostty", "brew upgrade"),
            row(4, "Mail", "Inbox"),
        ]
        #expect(ids(JumpSearch.matches(rows, query: "ghost")) == [2, 3, 1])
    }

    @Test("an app name that starts with the query outranks one containing it")
    func appPrefixFirst() {
        let rows = [row(1, "Superhuman", "x"), row(2, "Human", "y")]
        #expect(ids(JumpSearch.matches(rows, query: "hum")) == [2, 1])
    }

    @Test("a title word starting with the query outranks a match inside one")
    func titleWordStartFirst() {
        let rows = [
            row(1, "Notes", "Unplanned"),
            row(2, "Notes", "The plan"),
        ]
        let matches = JumpSearch.matches(rows, query: "plan")
        #expect(ids(matches) == [2, 1])
        let title = matches[0].entry.title
        #expect(matches[0].titleRange.map { String(title[$0]) } == "plan")
    }

    @Test("an app match outranks every title match")
    func appBeforeTitle() {
        let rows = [row(1, "Mail", "Notes draft"), row(2, "Notes", "x")]
        #expect(ids(JumpSearch.matches(rows, query: "notes")) == [2, 1])
    }

    @Test("case and accents are ignored; the range is the original's")
    func foldsCaseAndAccents() {
        let rows = [row(1, "Notes", "Le CAFÉ du coin")]
        let matches = JumpSearch.matches(rows, query: "cafe")
        let title = rows[0].title
        #expect(matches.count == 1)
        #expect(matches[0].titleRange.map { String(title[$0]) } == "CAFÉ")
    }

    @Test("a hidden app matches by name only and ranks below windows")
    func hiddenRanksLast() {
        let rows = [
            row(9, "Spotify", "", status: .hidden),
            row(1, "Notes", "Spotify playlist"),
            row(8, "Mail", "", status: .hidden),
        ]
        #expect(ids(JumpSearch.matches(rows, query: "spot")) == [1, 9])
        #expect(JumpSearch.matches(rows, query: "playlist").count == 1)
    }

    @Test("a row matching nothing is dropped")
    func noMatchDrops() {
        let rows = [row(1, "Mail", "Inbox")]
        #expect(JumpSearch.matches(rows, query: "zzq").isEmpty)
    }
}
