import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket list's Pocket Keys section (#2923 ▸ Ruling 1): one
/// header above the apps' own pocket windows, in the header ink,
/// and each such row's key at its trailing end, before the check
/// column, the title wrapping short of it.
@Suite("Bar peek Pocket Keys section", .serialized)
@MainActor
struct BarPeekPocketKeysTests {
    private func row(_ id: UInt32, _ app: String) -> BarWindowRow {
        BarWindowRow(
            window: WindowID(id),
            pid: pid_t(id),
            app: app,
            title: "Window \(id)",
            icon: nil
        )
    }

    private func content(keyed: Bool) -> BarPeekContent {
        BarPeekContent(
            rows: [row(1, "Safari"), row(2, "Notes")],
            checks: true,
            keyed: keyed ? [row(9, "Ghostty"), row(8, "Mail")] : [],
            chord: { $0 == WindowID(9) ? "⌃⌥T" : nil }
        )
    }

    @Test("one header above the keyed groups, and each key drawn")
    func headerAndKeys() throws {
        LocalizationManager.shared.select("en")
        let body = BarPeekBody()
        _ = body.layout(content(keyed: true), shelf: KiwiShelf(), hidden: 0)
        let header = try #require(body.sectionHeader)
        #expect(header.stringValue == "Pocket Keys")
        #expect(body.chords.map(\.stringValue) == ["⌃⌥T"])
        let titles = body.labels.filter { $0.stringValue.hasPrefix("Window") }
        let ghostty = try #require(
            titles.first { $0.stringValue == "Window 9" }
        )
        let safari = try #require(
            titles.first { $0.stringValue == "Window 1" }
        )
        // Below the general groups, above the first keyed one.
        #expect(header.frame.minY > safari.frame.maxY)
        #expect(header.frame.maxY < ghostty.frame.minY)
        // The key stands past its title, inside the wrap width.
        let key = try #require(body.chords.first)
        #expect(key.frame.minX >= ghostty.frame.maxX)
        #expect(key.frame.minY == ghostty.frame.minY)
    }

    /// Short rows leave the header the widest line: it keeps one.
    @Test("the header sets the width where it is the widest line")
    func headerFitsUnwrapped() throws {
        LocalizationManager.shared.select("en")
        let short = BarWindowRow(
            window: WindowID(9),
            pid: 9,
            app: "A",
            title: "W",
            icon: nil
        )
        let body = BarPeekBody()
        _ = body.layout(
            BarPeekContent(rows: [], checks: true, keyed: [short]),
            shelf: KiwiShelf(),
            hidden: 0
        )
        let header = try #require(body.sectionHeader)
        #expect(header.frame.width >= BarPeekBody.natural(header))
    }

    @Test("a list with no keyed window draws no section")
    func noSectionWithoutKeys() {
        let body = BarPeekBody()
        _ = body.layout(content(keyed: false), shelf: KiwiShelf(), hidden: 0)
        #expect(body.sectionHeader == nil)
        #expect(body.chords.isEmpty)
    }
}
