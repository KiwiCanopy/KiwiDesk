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

    /// `let foo = NSMenuItem(` → "foo", once per construction.
    private func constructedRows(_ source: String) -> [String] {
        source.split(separator: "\n").compactMap { line in
            guard line.contains("= NSMenuItem(") else { return nil }
            return
                line
                .split(separator: "=")
                .first?
                .split(whereSeparator: \.isWhitespace)
                .last
                .map(String.init)
        }
    }

    /// `foo.isEnabled =` → "foo", once per statement.
    private func statedRows(_ source: String) -> [String] {
        source.split(separator: "\n").compactMap { line in
            guard let head = line.range(of: ".isEnabled") else {
                return nil
            }
            return line[..<head.lowerBound]
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
        let source = try source(Self.builder)
        // `.separator()` constructs no `NSMenuItem` and has no
        // enablement to state, so it never enters the counts.
        let built = constructedRows(source)
        let stated = statedRows(source)
        #expect(
            built.count > 0,
            "the scan found no rows at all — has the builder moved?"
        )
        let exempt = Set(Self.statedByTheCaller.map(\.row))
        for name in Set(built) where !exempt.contains(name) {
            let constructions = built.filter { $0 == name }.count
            let statements = stated.filter { $0 == name }.count
            #expect(
                statements >= constructions,
                Comment(
                    rawValue:
                        "`\(name)` is constructed \(constructions) "
                        + "time(s) in \(Self.builder) and states "
                        + "isEnabled \(statements) time(s). A row "
                        + "that states nothing is enabled by "
                        + "default, which is what #802 costs once "
                        + "autoenablesItems is off — state it on "
                        + "that row, or add an entry naming who "
                        + "states it."
                )
            )
        }
    }

    @Test("The exempt row really is constructed here")
    func exemptRowsExist() throws {
        let built = Set(constructedRows(try source(Self.builder)))
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
