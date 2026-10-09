import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The cross-session match key (#1385 ruling 2026-10-09): the app
/// first, the title only once titles settle, then the rank; open
/// for late arrivals until it is closed. The rows are the
/// measured restart's (the 2026-10-09 step 3 comment). Pure and
/// clockless: `settle()` and `close()` are the passes'.
@Suite("Cross-session match key (#1385)")
struct CrossSessionMatchTests {
    private let armed = Date(timeIntervalSince1970: 9000)
    private let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    /// A snapshot with `rows` filed per Space, old ids from 500.
    private func snapshot(
        _ rows: [(space: String, app: String?, title: String)]
    ) -> StateSnapshot {
        var windows: [StateSnapshot.WindowRecord] = []
        var spaces: [String: [WindowID]] = [:]
        var order: [String] = []
        for (index, row) in rows.enumerated() {
            let id = WindowID(UInt32(500 + index))
            windows.append(
                .init(id: id, frame: frame, app: row.app, title: row.title)
            )
            if spaces[row.space] == nil { order.append(row.space) }
            spaces[row.space, default: []].append(id)
        }
        return StateSnapshot(
            windows: windows,
            spaces: order.map {
                .init(space: Space(id: SpaceID($0), windows: spaces[$0]!))
            },
            activeSpace: "1",
            capturedAt: armed
        )
    }

    private func match(
        _ rows: [(space: String, app: String?, title: String)],
        exists: @escaping (SpaceID) -> Bool = { _ in true }
    ) -> CrossSessionMatch {
        CrossSessionMatch(snapshot(rows), exists: exists)
    }

    private func live(
        _ id: UInt32,
        _ app: String,
        _ title: String
    ) -> CrossSessionMatch.Candidate {
        .init(id: WindowID(id), app: app, title: title)
    }

    /// window id → the Space its pair names.
    private func spaces(
        _ pairs: [(window: WindowID, record: CrossSessionMatch.Record)]
    ) -> [UInt32: String] {
        Dictionary(
            uniqueKeysWithValues: pairs.map {
                ($0.window.raw, $0.record.space.raw)
            }
        )
    }

    private func settled(
        _ rows: [(space: String, app: String?, title: String)]
    ) -> CrossSessionMatch {
        var m = match(rows)
        m.settle()
        return m
    }

    @Test("An app with one record and one window pairs at once")
    func uniqueAppPairsAtOnce() {
        let m = match([
            ("1", "com.ghostty", "~/unixporn"),
            ("5", "com.settings", "Anmeldeobjekte"),
        ])
        // System Settings came back untitled: the app alone pairs.
        let pairs = m.pairs([
            live(1, "com.ghostty", "~/unixporn"),
            live(2, "com.settings", ""),
        ])
        #expect(spaces(pairs) == [1: "1", 2: "5"])
    }

    @Test("A title pairs only once titles settle")
    func titleWaitsForTheSettle() {
        var m = match([
            ("1", "com.antigravity", "Antigravity IDE"),
            ("4", "com.antigravity", "KiwiDesk — Preview"),
        ])
        let windows = [
            live(1, "com.antigravity", "KiwiDesk — Preview"),
            live(2, "com.antigravity", "Antigravity IDE"),
        ]
        #expect(m.pairs(windows).isEmpty)
        m.settle()
        #expect(spaces(m.pairs(windows)) == [1: "4", 2: "1"])
    }

    /// Three windows share one title: each lands in a Space of its
    /// app, in an order the match does not promise.
    @Test("Identical titles go back to their app's Spaces")
    func identicalTitlesKeepTheirSpaces() {
        let m = settled([
            ("5", "app.zen", "Zen Browser"),
            ("1", "app.zen", "Zen Browser"),
            ("5", "app.zen", "Zen Browser"),
        ])
        let pairs = m.pairs((1...3).map { live($0, "app.zen", "Zen Browser") })
        #expect(pairs.count == 3)
        #expect(spaces(pairs).values.sorted() == ["1", "5", "5"])
    }

    /// Claude reopened one of two windows: the title takes its
    /// record, and an unmatched title falls back to rank.
    @Test("After the title, the rank")
    func rankAfterTheTitle() {
        let m = settled([
            ("5", "com.claude", "Claude"),
            ("5", "com.claude", ""),
            ("2", "com.other", "A"),
            ("4", "com.other", "B"),
        ])
        let pairs = m.pairs([
            live(1, "com.claude", "Claude"), live(2, "com.other", "X"),
        ])
        #expect(pairs.map(\.record.id.raw).sorted() == [500, 502])
        #expect(spaces(pairs) == [1: "5", 2: "2"])
    }

    @Test("A closed match pairs nothing")
    func closedPairsNothing() {
        var m = match([("2", "com.late", "Late")])
        let window = [live(9, "com.late", "Late")]
        #expect(m.pairs(window).count == 1)
        #expect(m.close() == 1)
        #expect(m.pairs(window).isEmpty)
    }

    @Test("A committed or user-filed window is never taken")
    func placedIsNeverTaken() {
        var m = settled([("2", "com.a", "A"), ("3", "com.a", "A")])
        let first = m.pairs([live(1, "com.a", "A")])
        m.commit(first)
        #expect(m.pending.count == 1)
        #expect(m.pairs([live(1, "com.a", "A")]).isEmpty)
        m.placed.insert(WindowID(2))
        #expect(m.pairs([live(2, "com.a", "A")]).isEmpty)
    }

    /// An older build's record has no key; a Space the live
    /// arrangement lacks takes nothing.
    @Test("Keyless records and missing Spaces are not pending")
    func pendingNeedsAKeyAndASpace() {
        let m = match(
            [("1", nil, "Old"), ("9", "com.a", "Gone"), ("2", "com.a", "")],
            exists: { $0 != SpaceID("9") }
        )
        #expect(m.pending.map(\.space.raw) == ["2"])
    }
}
