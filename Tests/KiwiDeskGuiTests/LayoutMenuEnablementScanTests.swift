import Foundation
import Testing

@testable import KiwiDesk

/// Every row the Layout submenu builds states its own
/// `isEnabled` (#802).
///
/// **Why a source scan and not an assertion on the built menu.**
/// A `guard-prover` run (2026-08-17) proved the obvious runtime
/// assertions inert: `NSMenuItem.isEnabled` defaults to `true`, so
/// deleting a `row.isEnabled = true` reds nothing, while #802's
/// defect class is precisely *forgetting to state it* once
/// `autoenablesItems` is off. Those runtime checks pin the
/// explicit-disable direction and are kept for it; they cannot see
/// an omission, and nothing headless can — AppKit's own
/// display-time validation never runs in a test.
///
/// So the omission is guarded where it is visible: in the source.
/// Not `@MainActor`, deliberately — it reads a file and counts, so
/// it has no business on an actor whose budget the heavy scanning
/// suites already share (`SettingsThemeWiringTests` is the
/// precedent).
@Suite("Layout menu rows state their enablement (#802)")
struct LayoutMenuEnablementScanTests {
    private static let builder =
        "Sources/KiwiDesk/StatusItemController+Layout.swift"

    /// Rows constructed in the builder that state their enablement
    /// somewhere ELSE, and where. One entry today.
    ///
    /// The entry names the statement that IS its reason, so an
    /// exemption whose grounds have gone reds rather than
    /// balancing the count quietly — the idiom
    /// `SettingsBorderedSealTests` uses for `borderedExempt`.
    /// `row` is the BINDING NAME in the builder, not prose — the
    /// pairing above keys on it, so an exemption has to name the
    /// thing it exempts.
    private static let statedByTheCaller:
        [(row: String, statedIn: String, needle: String)] = [
            (
                // The Layout submenu's own parent row, which is
                // added to the OUTER menu; that builder decides
                // its enablement from the boot phase (#802), so
                // stating it here would fight the caller.
                row: "parent",
                statedIn:
                    "Sources/KiwiDesk/StatusItemController+Menu.swift",
                needle: "layout.isEnabled"
            )
        ]

    private func source(_ path: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
        return SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    /// The builder split into its function bodies, so a binding
    /// name is paired within the scope that declares it.
    ///
    /// Pairing by NAME alone is a file-level total in miniature:
    /// `item` is bound in two functions, and stating it twice in
    /// one while stating it zero times in the other balances the
    /// count while a whole submenu ships unstated. A
    /// `guard-prover` round forged exactly that (2026-08-17).
    private func scopes(_ source: String) -> [String] {
        // Split on the func/var boundaries this file writes. Crude
        // but total for this builder: every row is constructed
        // inside one of them, and a row moved outside a function
        // is caught by the count check instead.
        var scopes: [String] = []
        var current = ""
        for line in source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let text = String(line)
            if text.hasPrefix("    func ")
                || text.hasPrefix("    private func ")
                || text.hasPrefix("    @objc func ")
            {
                scopes.append(current)
                current = text
            } else {
                current += "\n" + text
            }
        }
        scopes.append(current)
        return scopes
    }

    /// Every `NSMenuItem(` construction in a scope, with the name
    /// it is bound to — or `nil` for one bound to nothing.
    ///
    /// An inline `addItem(NSMenuItem(…))` is ordinary AppKit and
    /// this file already writes `addItem(.separator())`, so a row
    /// with no binding is the likeliest way to add one. It cannot
    /// state its own enablement at all, which is why it is
    /// reported rather than skipped (`guard-prover`, 2026-08-17).
    private func constructedRows(_ scope: String) -> [String?] {
        scope.split(separator: "\n").compactMap { line in
            guard line.contains("NSMenuItem(") else { return nil }
            guard line.contains("= NSMenuItem(") else {
                return String?.none  // constructed, bound to nothing
            }
            return
                line
                .split(separator: "=")
                .first?
                .split(whereSeparator: \.isWhitespace)
                .last
                .map(String.init)
        }
    }

    /// `foo.isEnabled =` → "foo", once per statement, ignoring any
    /// inside a string literal.
    ///
    /// A statement's text inside a string counts otherwise — a
    /// `toolTip` mentioning `entry.isEnabled` stood in for the
    /// real one, which is the same class `gui.md` already records
    /// for comments.
    private func statedRows(_ scope: String) -> [String] {
        scope.split(separator: "\n").compactMap { line in
            let outsideStrings = line.split(separator: "\"")
                .enumerated()
                .filter { $0.offset % 2 == 0 }
                .map(\.element)
                .joined(separator: " ")
            guard
                let head = outsideStrings.range(of: ".isEnabled")
            else { return nil }
            return outsideStrings[..<head.lowerBound]
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .last
                .map(String.init)
        }
    }

    /// **Counted per ROW, never per file.**
    ///
    /// A file-level total is forgeable, and a `guard-prover` run
    /// forged it (2026-08-17): adding `parent.isEnabled = true`
    /// while deleting `entry.isEnabled = true` keeps a file total
    /// balanced — 5 built, 4 stated + 1 exempt — while stripping
    /// enablement from every clickable mode row in the menu. It
    /// shipped 3429 tests green. Pairing each statement to the
    /// binding it names is what stops one row paying for another.
    @Test("Every constructed row states its OWN isEnabled")
    func everyRowStatesEnablement() throws {
        let whole = try source(Self.builder)
        // `.separator()` constructs no `NSMenuItem` and has no
        // enablement to state, so it never enters the counts.
        let exempt = Set(Self.statedByTheCaller.map(\.row))
        var total = 0
        for scope in scopes(whole) {
            let built = constructedRows(scope)
            let stated = statedRows(scope)
            total += built.count
            // A row bound to nothing cannot state its own
            // enablement, so it is a failure rather than a gap.
            #expect(
                !built.contains(where: { $0 == nil }),
                Comment(
                    rawValue:
                        "\(Self.builder) constructs an NSMenuItem "
                        + "bound to no name, so nothing can state "
                        + "its isEnabled — bind it to a `let` and "
                        + "state it (#802)."
                )
            )
            for name in Set(built.compactMap { $0 })
            where !exempt.contains(name) {
                let constructions = built.filter { $0 == name }
                    .count
                let statements = stated.filter { $0 == name }.count
                #expect(
                    statements >= constructions,
                    Comment(
                        rawValue:
                            "`\(name)` is constructed "
                            + "\(constructions) time(s) in this "
                            + "scope of \(Self.builder) and states "
                            + "isEnabled \(statements) time(s). A "
                            + "row that states nothing is enabled "
                            + "by default, which is what #802 "
                            + "costs once autoenablesItems is off "
                            + "— state it on that row, or add an "
                            + "entry naming who states it."
                    )
                )
            }
        }
        #expect(
            total > 0,
            "the scan found no rows at all — has the builder moved?"
        )
    }

    @Test("The exempt row really is constructed here")
    func exemptRowsExist() throws {
        let whole = try source(Self.builder)
        let built = Set(
            scopes(whole).flatMap { constructedRows($0) }
                .compactMap { $0 }
        )
        for entry in Self.statedByTheCaller {
            // An exemption for a row the builder no longer makes is
            // a licence sitting open for whoever reuses the name.
            #expect(
                built.contains(entry.row),
                Comment(
                    rawValue:
                        "`\(entry.row)` is exempted but no longer "
                        + "constructed in \(Self.builder)"
                )
            )
        }
    }

    @Test("Each exemption's own statement still exists")
    func exemptionsRestOnSomething() throws {
        for entry in Self.statedByTheCaller {
            let source = try source(entry.statedIn)
            #expect(
                source.occurrences(of: entry.needle) > 0,
                Comment(
                    rawValue:
                        "\(entry.row) is exempt because "
                        + "\(entry.statedIn) states "
                        + "`\(entry.needle)`, which that file no "
                        + "longer contains — the count balances "
                        + "while the reason has gone"
                )
            )
        }
    }

    /// The switch the whole rule hangs off: with auto-enabling ON,
    /// AppKit re-enables at display time any row whose target
    /// responds to its action, so a row that WORKS cannot be
    /// dimmed. Every menu this builder creates turns it off — and
    /// the flag does not inherit, so each `NSMenu()` needs its own.
    @Test("Every menu the builder creates turns auto-enabling off")
    func everyMenuDisablesAutoEnable() throws {
        let source = try source(Self.builder)
        let menus = source.occurrences(of: "NSMenu()")
        let disabled = source.occurrences(
            of: "autoenablesItems = false"
        )
        #expect(menus > 0)
        #expect(
            disabled == menus,
            Comment(
                rawValue:
                    "\(Self.builder) creates \(menus) NSMenu(s) "
                    + "and turns auto-enabling off \(disabled) "
                    + "time(s). The flag is per menu and does not "
                    + "inherit from a parent."
            )
        )
    }
}
