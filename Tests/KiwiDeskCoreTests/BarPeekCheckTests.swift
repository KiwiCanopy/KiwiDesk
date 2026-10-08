import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The peek's check (#2063, owner ruling): a list's focused row
/// carries a checkmark in a column PAST the titles' wrap width, so
/// every title wraps where it would without it, on the first line
/// of a wrapped title, in the row's own ink.
@Suite("Bar hover peek check", .serialized)
@MainActor
struct BarPeekCheckTests {
    private static let long =
        "KiwiCV - Lebenslauf Vorlagen kostenlos & KI-Optimierung, "
        + "a title long enough to wrap twice"

    private func content(checks: Bool, focus: UInt32?) -> BarPeekContent {
        BarPeekContent(
            rows: [(1, Self.long), (2, "Short")].map { id, title in
                BarWindowRow(
                    window: WindowID(id),
                    pid: 1,
                    app: "Zen",
                    title: title,
                    icon: nil
                )
            },
            checks: checks,
            focus: focus.map(WindowID.init)
        )
    }

    @Test("The column sits past the wrap width: no title rewraps")
    func columnLeavesWrappingAlone() {
        let plain = BarPeekBody()
        let size = plain.layout(
            content(checks: false, focus: nil),
            shelf: KiwiShelf(),
            hidden: 0
        )
        let listed = BarPeekBody()
        let checked = listed.layout(
            content(checks: true, focus: nil),
            shelf: KiwiShelf(),
            hidden: 0
        )
        #expect(listed.labels.map(\.frame) == plain.labels.map(\.frame))
        #expect(
            checked.width - size.width
                == BarPeekBody.Metrics.checkColumn
        )
        #expect(listed.check == nil, "reserved, nothing checked")
    }

    @Test("The focused row's check: first line, trailing edge, row ink")
    func checkSitsOnTheFirstLine() throws {
        let body = BarPeekBody()
        let size = body.layout(
            content(checks: true, focus: 1),
            shelf: KiwiShelf(),
            hidden: 0
        )
        let check = try #require(body.check)
        let row = try #require(
            body.labels.first { $0.stringValue == Self.long }
        )
        let line = BarPeekBody.lineHeight(row.font)
        try #require(row.frame.height > 1.5 * line, "the title wraps")
        #expect(check.frame.maxX == size.width - BarPeekBody.Metrics.padH)
        #expect(check.frame.minX >= row.frame.maxX)
        #expect(check.frame.midY < row.frame.minY + line, "first line")
        #expect(check.contentTintColor == row.textColor)
        let target = try #require(
            body.targets.first { $0.action == .window(WindowID(1)) }
        )
        #expect(target.frame.contains(check.frame), "the fill covers it")
        #expect(target.inks.contains { $0 === check }, "hover lifts it")
    }
}
