import Foundation
import Testing

/// The primitive sweeps behind the catalog (#277 part 2): the
/// shapes that must ONLY exist inside the blessed files, so a
/// feature call site cannot re-grow the hand-anchoring
/// conventions the catalog retired. Fail-shut throughout: a new
/// site either moves to the primitive or is allow-listed here
/// with its reason.
@Suite("Settings anchor primitives")
struct SettingsAnchorPrimitiveTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private func occurrences(
        of needle: String,
        excluding allowed: Set<String>
    ) throws -> [String] {
        var hits: [String] = []
        for file in try SourceScan.swiftSources(under: settingsDir)
        where !allowed.contains(file.lastPathComponent) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count = source.occurrences(of: needle)
            if count > 0 {
                hits.append("\(file.lastPathComponent) ×\(count)")
            }
        }
        return hits
    }

    /// Every drawer renders through `SettingsDisclosure`, which
    /// owns the anchor pairing and the auto-expand. Part 1's six
    /// dead entries were bare `DisclosureGroup`s nobody anchored
    /// — with the wrapper mandatory, the mistake has no home.
    @Test("no bare DisclosureGroup outside the wrapper")
    func bareDisclosuresAreConfined() throws {
        let hits = try occurrences(
            of: "DisclosureGroup(",
            excluding: [
                // The wrapper itself.
                "SettingsDisclosure.swift",
                // The per-Space Overrides… popover's dormant
                // drawer: the popover opens from a row button,
                // not a destination, so no reveal can target
                // its interior — a wrapper would promise an
                // auto-expand that can never fire. Its label
                // also interpolates a live count, which a
                // static catalog cannot carry.
                "SpaceOverrideRows+Footer.swift",
            ]
        )
        #expect(
            hits.isEmpty,
            Comment(
                rawValue:
                    "bare DisclosureGroup(s) outside "
                    + "SettingsDisclosure — wrap them, or "
                    + "allow-list with a reason: "
                    + hits.joined(separator: ", ")
            )
        )
    }

    /// Declarations live in the catalog, full stop. An inline
    /// construction at a view would render and anchor a control
    /// the index never enumerates — findable never, the exact
    /// silent gap the one-list design closes.
    @Test("no descriptor construction outside the catalog")
    func descriptorConstructionIsConfined() throws {
        for needle in ["SettingsControl(", "SettingsDrawer("] {
            let hits = try occurrences(
                of: needle,
                excluding: [
                    "SettingsControl.swift",
                    "SettingsCatalog.swift",
                ]
            )
            #expect(
                hits.isEmpty,
                Comment(
                    rawValue:
                        "\(needle)…) constructed outside the "
                        + "catalog — declare it in "
                        + "SettingsCatalog: "
                        + hits.joined(separator: ", ")
                )
            )
        }
    }

    /// The raw modifiers stay inside the primitives that encode
    /// the pairing rules (flash on the label, anchor outside
    /// card chrome). `GapsEditor` hosts `GapRow`, the anchored
    /// row shape, until a shared row primitive exists.
    @Test("searchAnchor/searchFlash only in the primitives")
    func anchorModifiersAreConfined() throws {
        let allowed: Set<String> = [
            // The definitions.
            "SettingsReveal.swift",
            // The three primitives that apply them.
            "SettingsSection.swift",
            "SettingsDisclosure.swift",
            "GapsEditor.swift",
        ]
        for needle in [".searchAnchor(", ".searchFlash("] {
            let hits = try occurrences(
                of: needle,
                excluding: allowed
            )
            #expect(
                hits.isEmpty,
                Comment(
                    rawValue:
                        "\(needle)…) applied outside the "
                        + "primitives — route through "
                        + "SettingsSection / SettingsDisclosure "
                        + "or an anchored row shape: "
                        + hits.joined(separator: ", ")
                )
            )
        }
        // And the needles must still match somewhere, or the
        // sweep is checking nothing (a guard that cannot fire
        // is worse than none — part-1 lesson).
        let primitiveDir = settingsDir
        var total = 0
        for file in try SourceScan.swiftSources(
            under: primitiveDir
        ) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            total += source.occurrences(of: ".searchAnchor(")
        }
        #expect(total >= 3)
    }
}
