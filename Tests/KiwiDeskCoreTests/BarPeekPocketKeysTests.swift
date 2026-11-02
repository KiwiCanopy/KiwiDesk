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

    /// Ruling 4 and 5: the key in the system face whatever the bar
    /// font, in its own column at least `chordGap` past every title,
    /// every key ending on one trailing edge.
    @Test("keys stand in their own column, in the system face")
    func keyColumn() throws {
        LocalizationManager.shared.select("en")
        var shelf = KiwiShelf()
        shelf.fontFamily = KiwiShelf.systemMonospacedFontFamily
        let long = BarWindowRow(
            window: WindowID(8),
            pid: 8,
            app: "Notes",
            title: "Shopping list",
            icon: nil
        )
        let short = BarWindowRow(
            window: WindowID(9),
            pid: 9,
            app: "Code",
            title: "W",
            icon: nil
        )
        let body = BarPeekBody()
        _ = body.layout(
            BarPeekContent(
                rows: [],
                checks: true,
                keyed: [long, short],
                chord: { $0 == WindowID(9) ? "⌥A" : "⌃⌥N" }
            ),
            shelf: shelf,
            hidden: 0
        )
        #expect(body.chords.count == 2)
        let titles = body.labels.filter {
            ["Shopping list", "W"].contains($0.stringValue)
        }
        let first = try #require(titles.first)
        // The key's face is the system's, the title's the bar's.
        let system = BarFont.chordFont(ofSize: 13)
        #expect(body.chords.allSatisfy { $0.font == system })
        #expect(first.font != system)
        // One trailing edge, clear of the longest title by the gap.
        let ends = Set(body.chords.map(\.frame.maxX))
        #expect(ends.count == 1)
        let longest =
            titles.map {
                $0.frame.minX + BarPeekBody.natural($0)
            }.max() ?? 0
        let lead = body.chords.map(\.frame.minX).min() ?? 0
        #expect(lead - longest >= BarPeekBody.Metrics.chordGap)
    }

    @Test("a list with no keyed window draws no section")
    func noSectionWithoutKeys() {
        let body = BarPeekBody()
        _ = body.layout(content(keyed: false), shelf: KiwiShelf(), hidden: 0)
        #expect(body.sectionHeader == nil)
        #expect(body.chords.isEmpty)
    }
}
