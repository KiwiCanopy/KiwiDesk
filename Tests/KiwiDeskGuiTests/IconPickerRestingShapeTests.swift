import Foundation
import Testing

@testable import KiwiDesk

/// The icon picker opens in ONE resting shape for every caller
/// (#1379, #1357): the Symbols tab, an empty search, Recents
/// showing — the argument is design-decisions ▸ Icons. The reset
/// rides the popover's own dismissal rather than each closing
/// path, so a path added later cannot forget it — and that is a
/// CLASS: every popover holding a per-open search takes the same
/// hook (`AppPickerButton` was #1357's second member).
@Suite("Icon picker resting shape")
struct IconPickerRestingShapeTests {
    private var guiRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    private func squashed(_ url: URL) throws -> String {
        SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    private var source: String {
        get throws {
            try squashed(
                guiRoot.appendingPathComponent(
                    "Settings/Components/Icons/IconPicker.swift"
                )
            )
        }
    }

    /// Every GUI file presenting a popover over a per-open
    /// `search` state, with the presentation binding's NAME read
    /// off the `.popover` call — a member spelling it otherwise
    /// cannot slip out of the census.
    private func searchPopovers() throws -> [(URL, binding: String)] {
        try SourceScan.swiftSources(under: guiRoot).compactMap {
            let s = try squashed($0)
            guard s.contains("@Stateprivatevarsearch="),
                let call = s.range(of: ".popover(isPresented:$")
            else { return nil }
            let name = s[call.upperBound...].prefix {
                $0.isLetter || $0.isNumber || $0 == "_"
            }
            return ($0, String(name))
        }
    }

    /// The brace-balanced body following `opener`, or nil when
    /// the opener is absent or occurs more than once.
    private func body(after opener: String, in s: String) -> String? {
        guard s.components(separatedBy: opener).count == 2,
            let start = s.range(of: opener)
        else { return nil }
        var depth = 0
        var i = start.upperBound
        var began = false
        while i < s.endIndex {
            let c = s[i]
            if c == "{" {
                depth += 1
                began = true
            } else if c == "}" {
                depth -= 1
                if began && depth == 0 {
                    return String(s[start.upperBound...i])
                }
            }
            i = s.index(after: i)
        }
        return nil
    }

    @Test("Symbols is the resting tab and the first segment")
    func symbolsLead() {
        #expect(IconPicker.IconTab.resting == .symbols)
        #expect(IconPicker.IconTab.allCases.first == .symbols)
    }

    /// The one `tab` state is private, so no caller can hand a
    /// tab in, and its initial value is the resting one by NAME,
    /// not a case a retune could leave behind.
    @Test("The picker opens on the resting tab with no caller switch")
    func opensOnTheRestingTab() throws {
        let s = try source
        #expect(s.components(separatedBy: "vartab:IconTab=").count == 2)
        #expect(s.contains("@Stateprivatevartab:IconTab=.resting"))
    }

    /// Both resets inside the one dismissal hook — a choice, the
    /// clear button and a click-away all close through `showing`.
    /// The hook's interior is glue: its presence, its single
    /// occurrence, the two writes and their ONE home are pinned —
    /// `search=""` twice (declaration, hook), `tab=.resting`
    /// once — so a reset re-derived beside `choose` reds.
    @Test("Search and tab reset when the popover closes")
    func resetsOnClose() throws {
        let s = try source
        let hook = try #require(
            body(after: ".onChange(of:showing)", in: s)
        )
        #expect(hook.contains("search=\"\""))
        #expect(hook.contains("tab=.resting"))
        #expect(s.components(separatedBy: "search=\"\"").count == 3)
        #expect(s.components(separatedBy: "tab=.resting").count == 2)
        // The hook is the ONLY writer of `tab` — an `.onAppear`
        // or a second hook re-selecting a tab would stay green on
        // the clauses above (guard-prover).
        #expect(s.components(separatedBy: "tab=").count == 2)
    }

    /// The class: every popover holding a per-open search clears
    /// it on the dismissal edge. The census is derived from the
    /// tree, and pinned non-empty so a renamed state cannot
    /// shrink it to nothing.
    @Test("Every search popover clears its search on close")
    func everySearchPopoverResets() throws {
        let members = try searchPopovers()
        #expect(members.count >= 2)
        for (url, binding) in members {
            let hook = body(
                after: ".onChange(of:\(binding))",
                in: try squashed(url)
            )
            #expect(
                hook?.contains("search=\"\"") == true,
                Comment(
                    rawValue:
                        "\(url.lastPathComponent) reopens on its "
                        + "last search (#1357)"
                )
            )
        }
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
