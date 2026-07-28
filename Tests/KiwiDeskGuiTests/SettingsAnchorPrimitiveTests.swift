import Foundation
import Testing

/// The primitive sweeps behind the catalog (#277 part 2): the
/// shapes that must ONLY exist inside the blessed files, so a
/// feature call site cannot re-grow the hand-anchoring
/// conventions the catalog retired. Fail-shut throughout: a new
/// site either moves to the primitive or is allow-listed here
/// with its reason.
///
/// The reveal contract these defend is stated once, at the code
/// (`SettingsReveal.swift`). Each test below says only what it
/// checks and why a source scan is the tool — the type system
/// closes the rest (#573).
@Suite("Settings anchor primitives")
struct SettingsAnchorPrimitiveTests {
    /// Rooted at the whole GUI target, not `Settings/`: the
    /// modifiers are `internal` `View` extensions, so a call site
    /// in `Shortcuts/` would be just as wrong and was previously
    /// unswept. Zero hits live outside `Settings/` today, so the
    /// wider root is free and closes it permanently.
    private var guiDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    /// `file -> count` for every file containing `needle`.
    private func occurrences(
        of needle: String,
        excluding allowed: Set<String>
    ) throws -> [(name: String, count: Int)] {
        var hits: [(name: String, count: Int)] = []
        for file in try SourceScan.swiftSources(under: guiDir)
        where !allowed.contains(file.lastPathComponent) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count = source.occurrences(of: needle)
            if count > 0 {
                hits.append((file.lastPathComponent, count))
            }
        }
        return hits
    }

    private func describe(
        _ hits: [(name: String, count: Int)]
    ) -> String {
        hits.map { "\($0.name) ×\($0.count)" }
            .joined(separator: ", ")
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
                    + describe(hits)
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
        for file in try SourceScan.swiftSources(under: guiDir)
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
                        + "SettingsCatalog: " + describe(hits)
                )
            )
        }
    }

    /// `searchAnchor` is a one-line `.id()` wrapper, so a raw
    /// `.id(control.id)` at a call site is a third door into the
    /// same mistake: it anchors without washing, and sealing the
    /// halves does not close it. A search hit then scrolls
    /// correctly and flashes nothing — silent, and the most
    /// plausible regression of all, since `.id()` is ordinary
    /// SwiftUI rather than anything this subsystem invented.
    @Test("no ad-hoc .id() outside collection identity")
    func identityModifiersAreConfined() throws {
        let hits = try occurrences(
            of: ".id(",
            excluding: [
                // Collection identity, not search identity: each
                // keys a row inside a ForEach so edits and
                // reorders don't recycle state onto the wrong
                // row. Nothing here is a reveal target.
                "KeybindingNavRow.swift",
                "KeybindingAppGroup.swift",
                "AdvancedLuaGroup.swift",
                // Locale identity: `L()` is not observable state,
                // so a language change rebuilds the whole hosting
                // root by keying it on the locale. Deliberately
                // the coarsest `.id()` in the app — the opposite
                // end of the scale from an anchor, and it would
                // swallow one if anybody nested them.
                "LocaleScopedRoot.swift",
            ]
        )
        #expect(
            hits.isEmpty,
            Comment(
                rawValue:
                    ".id(…) applied outside collection identity "
                    + "— a search anchor takes "
                    + ".searchAnchored(control) so it cannot "
                    + "anchor without washing: " + describe(hits)
            )
        )
    }

    /// The files that may split the pair across chrome. Sealing
    /// the raw `String` halves closed the literal-id door but not
    /// this one: the typed container halves are `internal`, so
    /// `.searchAnchorCard(someControl)` compiles at any view in
    /// the target, where it anchors WITHOUT washing and mounts a
    /// second copy of an id the real section already owns —
    /// `scrollTo` then has two candidates. More plausible than
    /// the `.id()` door, too, since both surface on autocomplete
    /// for every `View` and read as an instruction.
    private let pairingPrimitives: Set<String> = [
        "SettingsReveal.swift",
        "SettingsSection.swift",
        "SettingsDisclosure.swift",
    ]

    @Test("the split halves stay inside the container shapes")
    func containerHalvesAreConfined() throws {
        for needle in [
            ".searchAnchorCard(", ".searchFlashHeader(",
        ] {
            let hits = try occurrences(
                of: needle,
                excluding: pairingPrimitives
            )
            #expect(
                hits.isEmpty,
                Comment(
                    rawValue:
                        "\(needle)…) applied outside the "
                        + "container shapes — a control that is "
                        + "its own scroll target takes "
                        + ".searchAnchored(control) whole: "
                        + describe(hits)
                )
            )
        }
    }

    /// The whole-pair primitive must stay reached-for: at zero
    /// call sites the next self-anchoring control has nothing to
    /// copy and reaches for `.id()` instead. Counts SITES, not
    /// files — two controls that later share a file must not read
    /// as a regression, and a 3→2 drop inside one file must not
    /// hide.
    @Test("self-anchoring controls reach for the primitive")
    func thePrimitiveStaysReachedFor() throws {
        let hits = try occurrences(
            of: ".searchAnchored(",
            excluding: ["SettingsReveal.swift"]
        )
        let sites = hits.reduce(0) { $0 + $1.count }
        #expect(
            sites >= 2,
            Comment(
                rawValue:
                    "searchAnchored is applied at \(sites) "
                    + "site(s); expected at least the two "
                    + "self-anchoring controls (GapRow, "
                    + "BarEditorPicker): " + describe(hits)
            )
        )
    }
}
