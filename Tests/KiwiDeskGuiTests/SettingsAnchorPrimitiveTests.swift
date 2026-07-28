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
    /// The files that may apply the raw `.searchAnchor` /
    /// `.searchFlash` halves: the definitions, plus the two
    /// primitives that must *split* the pair across a chrome
    /// boundary (flash on the header/label, anchor on the whole
    /// card). Every other shape — a self-anchoring control, whose
    /// wash and scroll target are one rect — takes
    /// `.settingsAnchor(_:)` whole and stays off this list
    /// (#573).
    private let pairingPrimitives: Set<String> = [
        // The definitions, and `settingsAnchor`'s one home.
        "SettingsReveal.swift",
        // The two split-pair primitives.
        "SettingsSection.swift",
        "SettingsDisclosure.swift",
    ]

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
        var catalogFiles: Set<String> = []
        for file in try SourceScan.swiftSources(under: settingsDir)
        where SettingsCatalogFiles.isCatalogFile(
            file.lastPathComponent
        ) {
            catalogFiles.insert(file.lastPathComponent)
        }
        for needle in ["SettingsControl(", "SettingsDrawer("] {
            let hits = try occurrences(
                of: needle,
                excluding: catalogFiles
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
    /// the pairing rules. Only a shape that must split the pair
    /// across chrome earns a slot; a self-anchoring control does
    /// not, and #573 moved the two that were here (`GapsEditor`'s
    /// rows, `BarEditorPicker`'s chips) onto `.settingsAnchor`
    /// rather than let the list reach three hand-encoded
    /// placements of the same rule.
    @Test("searchAnchor/searchFlash only in the primitives")
    func anchorModifiersAreConfined() throws {
        for needle in [".searchAnchor(", ".searchFlash("] {
            let hits = try occurrences(
                of: needle,
                excluding: pairingPrimitives
            )
            #expect(
                hits.isEmpty,
                Comment(
                    rawValue:
                        "\(needle)…) applied outside the "
                        + "primitives — a self-anchoring control "
                        + "takes .settingsAnchor(control) whole: "
                        + hits.joined(separator: ", ")
                )
            )
        }
    }

    /// Confinement alone leaves the primitives free to feed the
    /// halves badly, and both mistakes are silent — nothing
    /// crashes, a search hit simply lands nowhere:
    ///
    /// - a **literal** id (a typo, a hand-built string) is a
    ///   scroll target no search result points at, since the
    ///   index only ever emits `SettingsControl.id`;
    /// - **one half alone**, or the two fed *different* ids, is a
    ///   flash with nothing to scroll to, or the reverse.
    ///
    /// So per blessed file the two argument sets must be equal
    /// and non-empty, and no argument may carry a string literal.
    /// Sets, not counts: `SettingsDisclosure` anchors in each of
    /// its two chrome branches and flashes once.
    @Test("the raw halves are a matched, literal-free pair")
    func anchorHalvesAreMatchedPairs() throws {
        var seen: Set<String> = []
        for file in try SourceScan.swiftSources(under: settingsDir)
        where pairingPrimitives.contains(file.lastPathComponent) {
            let name = file.lastPathComponent
            seen.insert(name)
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let anchors = Set(
                SourceScan.firstArguments(
                    of: ".searchAnchor(",
                    in: source
                )
            )
            let flashes = Set(
                SourceScan.firstArguments(
                    of: ".searchFlash(",
                    in: source
                )
            )
            #expect(
                !anchors.isEmpty,
                Comment(
                    rawValue:
                        "\(name) is listed as a pairing "
                        + "primitive but applies neither half — "
                        + "drop it from the list, or the "
                        + "confinement guard is protecting "
                        + "nothing"
                )
            )
            #expect(
                anchors == flashes,
                Comment(
                    rawValue:
                        "\(name) anchors \(anchors.sorted()) but "
                        + "flashes \(flashes.sorted()) — a reveal "
                        + "scrolls to one id and washes another"
                )
            )
            for argument in anchors.union(flashes) {
                #expect(
                    !argument.contains("\""),
                    Comment(
                        rawValue:
                            "\(name) feeds a literal id "
                            + "'\(argument)' — pass a "
                            + "SettingsControl.id, which is the "
                            + "only thing the index emits"
                    )
                )
            }
        }
        // The list names files, so a rename would quietly empty
        // the sweep.
        #expect(seen == pairingPrimitives)
    }

    /// And the whole-pair primitive must stay reached-for. If it
    /// falls to zero call sites the next self-anchoring control
    /// has nothing to copy, and the confinement guard above turns
    /// from a signpost into a dead end. Two today: `GapsEditor`'s
    /// rows and `BarEditorPicker`'s chips.
    @Test("self-anchoring controls route through the primitive")
    func selfAnchoringControlsUseThePrimitive() throws {
        let hits = try occurrences(
            of: ".settingsAnchor(",
            excluding: ["SettingsReveal.swift"]
        )
        #expect(
            hits.count >= 2,
            Comment(
                rawValue:
                    "settingsAnchor is applied at "
                    + "\(hits.count) sites (expected the two "
                    + "self-anchoring controls at least): "
                    + hits.joined(separator: ", ")
            )
        )
    }
}
