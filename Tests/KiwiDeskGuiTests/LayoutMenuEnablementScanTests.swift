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
    private static let statedByTheCaller:
        [(row: String, statedIn: String, needle: String)] = [
            (
                row: "the Layout parent row",
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

    @Test("Every constructed row states isEnabled, or names who does")
    func everyRowStatesEnablement() throws {
        let source = try source(Self.builder)
        // `.separator()` is not an `NSMenuItem(` construction and
        // has no enablement to state, so it never enters the count.
        let built = source.occurrences(of: "NSMenuItem(")
        let stated = source.occurrences(of: ".isEnabled =")
        #expect(
            built > 0,
            "the scan found no rows at all — has the builder moved?"
        )
        #expect(
            stated + Self.statedByTheCaller.count == built,
            Comment(
                rawValue:
                    "\(Self.builder) builds \(built) row(s) and "
                    + "states isEnabled \(stated) time(s), with "
                    + "\(Self.statedByTheCaller.count) exempted. "
                    + "A row that states nothing is enabled by "
                    + "default, which is what #802 costs once "
                    + "autoenablesItems is off — state it, or add "
                    + "an entry naming who states it."
            )
        )
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
