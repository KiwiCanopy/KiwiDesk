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
        where SourceScan.isCatalogFile(
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
    /// Exact counts, not an exempt file set. A whole-file
    /// exemption would blind the guard to a SECOND `.id(` in one
    /// of these — and `KeybindingNavRow` is a real Settings row
    /// in the destination whose controls it would be tempted to
    /// anchor, so that blind spot sits exactly where the mistake
    /// would be made. Same idiom as `alternatelyMounted`: record
    /// the number, not the permission.
    ///
    /// Known limit worth naming rather than rediscovering: the
    /// needle carries a leading dot, so a *dotless* `id(...)`
    /// inside a `View` extension — the shape `searchAnchor`'s own
    /// body uses — is invisible here.
    private let identitySites: [String: Int] = [
        // Collection identity, not search identity: each keys a
        // row inside a ForEach so edits and reorders don't
        // recycle state onto the wrong row. Nothing here is a
        // reveal target.
        "KeybindingNavRow.swift": 1,
        "KeybindingAppGroup+Row.swift": 1,
        "AdvancedLuaGroup.swift": 1,
        // Locale identity: `L()` is not observable state, so a
        // language change rebuilds the whole hosting root by
        // keying it on the locale. Deliberately the coarsest
        // `.id()` in the app — the opposite end of the scale from
        // an anchor, and it would swallow one if anybody nested
        // them.
        "LocaleScopedRoot.swift": 1,
        // Navigation identity: the header search remounts per
        // destination, clearing its query and closing the
        // result panel — restored focus was re-opening stale
        // suggestions over every push/pop (owner, 2026-08-10;
        // `HomeSurfacingTests` pins the wire). Not a reveal
        // target: the field is chrome, and nothing inside the
        // remounted subtree anchors.
        "SettingsHeaderBar.swift": 1,
        // Navigation identity again, and for the same reason
        // one level out (17a): the detached preview card keeps
        // its travel in `@State`, and its structural position
        // is identical across a destination change, so without
        // a key an area you never dragged opens with its
        // preview parked where the last one was left. Not a
        // reveal target either — the card is chrome over the
        // pane, and the panel inside it anchors nothing.
        "SettingsView+Preview.swift": 1,
    ]

    @Test("no ad-hoc .id() outside collection identity")
    func identityModifiersAreConfined() throws {
        let hits = try occurrences(of: ".id(", excluding: [])
        var seen: Set<String> = []
        for hit in hits {
            seen.insert(hit.name)
            let allowed =
                identitySites[hit.name]
                .map(String.init) ?? "none"
            #expect(
                identitySites[hit.name] == hit.count,
                Comment(
                    rawValue:
                        "\(hit.name) applies .id(…) "
                        + "×\(hit.count), expected \(allowed) — "
                        + "a search anchor takes "
                        + ".searchAnchored(control) so it cannot "
                        + "anchor without washing"
                )
            )
        }
        // A renamed or deleted exempt file must not leave a stale
        // entry standing in for coverage it no longer provides.
        #expect(seen == Set(identitySites.keys))
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
            // The hoisted scroll half (#610): a bare scroll anchor
            // with its wash on the drawer label a level down. Just
            // as much a scroll-without-a-local-wash at a rogue call
            // site as the card half, so it earns the same seal.
            ".searchScrollAnchor(",
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
                    + "self-anchoring controls (GapRow, the "
                    + "Show-it-in toggles): " + describe(hits)
            )
        )
    }

    /// The hoisted-reveal door (#610) is a new reveal shape, so it
    /// earns the same confinement every other one carries. Confining
    /// the KEY NAME to its three blessed files — declared in
    /// `SettingsReveal`, published from `SettingsDisclosure`,
    /// collected in `SettingsSection` — closes the whole door at
    /// once: a feature file that cannot name `HoistedRevealAnchorsKey`
    /// can neither publish a spurious marker nor read one. That
    /// bubbling-`.preference` mistake is invisible to
    /// `containerHalvesAreConfined`, since the marker's own mount is
    /// legitimately in the section shape. Naming the key, not each
    /// modifier, keeps this robust to how the calls wrap.
    private let hoistKeyFiles: Set<String> = [
        "SettingsReveal.swift",
        "SettingsDisclosure.swift",
        "SettingsSection.swift",
    ]

    @Test("the hoisted-reveal key stays inside its shapes")
    func hoistedRevealKeyIsConfined() throws {
        let hits = try occurrences(
            of: "HoistedRevealAnchorsKey",
            excluding: hoistKeyFiles
        )
        #expect(
            hits.isEmpty,
            Comment(
                rawValue:
                    "HoistedRevealAnchorsKey named outside its "
                    + "three shapes (declare/publish/collect) — a "
                    + "feature site naming it can mount or read a "
                    + "spurious hoisted marker: " + describe(hits)
            )
        )
    }

    /// #610 must stay reached-for, the same floor
    /// `thePrimitiveStaysReachedFor` holds for `searchAnchored`.
    /// The id-pairing guard the old count check also did is now
    /// sealed by construction (marker id == the drawer's own
    /// published control), but its non-vacuity half is not — drop
    /// `scrollHoisted: true` from a call site and that drawer
    /// silently disembodies its heading again with a green suite.
    /// Five: Gaps ×2, the two bar colour drawers, App Bar overrides.
    @Test("hoisted drawers stay reached-for")
    func hoistedDrawersStayReachedFor() throws {
        let hits = try occurrences(
            of: "scrollHoisted: true",
            excluding: []
        )
        let sites = hits.reduce(0) { $0 + $1.count }
        #expect(
            sites >= 5,
            Comment(
                rawValue:
                    "scrollHoisted: true at \(sites) site(s); "
                    + "expected at least the five shipped hoists "
                    + "(Gaps per-edge/per-axis, App/Space bar "
                    + "colours, App Bar overrides): " + describe(hits)
            )
        )
    }
}
