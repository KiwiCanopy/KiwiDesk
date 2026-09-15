import Foundation
import Testing

@testable import KiwiDesk

/// The icon picker opens in ONE resting shape for every caller
/// (#1379, #1357): the Symbols tab, an empty search, Recents
/// showing. Symbols lead because a symbol takes the bar's item
/// tints while an emoji is untinted content the bar dims like an
/// app image, and Recents is one shared list — so there is no
/// per-caller default to leak through it. The reset rides the
/// popover's own dismissal rather than each closing path, so a
/// path added later cannot forget it.
@Suite("Icon picker resting shape")
struct IconPickerRestingShapeTests {
    private var source: String {
        get throws {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Icons/"
                        + "IconPicker.swift"
                )
            return SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
        }
    }

    @Test("Symbols is the resting tab and the first segment")
    func symbolsLead() {
        #expect(IconPicker.IconTab.resting == .symbols)
        #expect(IconPicker.IconTab.allCases.first == .symbols)
    }

    /// The `@State` is private, so no caller can hand a tab in;
    /// its initial value is the resting one by NAME, not a case a
    /// retune could leave behind.
    @Test("The picker opens on the resting tab with no caller switch")
    func opensOnTheRestingTab() throws {
        let s = try source
        #expect(s.contains("@Stateprivatevartab:IconTab=.resting"))
        #expect(!s.contains("vartab:IconTab=.emoji"))
    }

    /// Both resets in the one dismissal hook — a choice, the
    /// clear button and a click-away all close through `showing`.
    @Test("Search and tab reset when the popover closes")
    func resetsOnClose() throws {
        let s = try source
        #expect(
            s.contains(
                ".onChange(of:showing){_,isShowinginif!isShowing"
                    + "{search=\"\"tab=.resting}}"
            )
        )
    }

    /// Global search lists Symbol results above Emoji for the
    /// tab's reason, the special results staying first.
    @Test("Search results list symbols above emoji")
    func searchOrdersSymbolsFirst() throws {
        let s = try source
        let symbols = try #require(
            s.range(of: "choices:filtered(IconCatalog.symbols)")
        )
        let emoji = try #require(
            s.range(of: "choices:filtered(IconCatalog.emoji)")
        )
        let special = try #require(s.range(of: "specialResults"))
        #expect(special.lowerBound < symbols.lowerBound)
        #expect(symbols.lowerBound < emoji.lowerBound)
    }
}
