import Foundation
import Testing

/// "Grey, don't hide" (#171) had been written down and never
/// enforced: `Tests/KiwiDeskGuiTests/` contained **zero**
/// assertions about `.disabled` or `GreyOut`, which is why about
/// a dozen newer surfaces drifted. That absence — not the drift
/// — was the root cause (#520), so the sweep ships with a guard.
///
/// **Design the lens before the list.** The #406 audit's sharpest
/// lesson was `SidebarSearchParityTests`, whose blind spot was
/// structural: it matched only `SettingsSection(…)`, so every
/// `DisclosureGroup` was invisible and no test *could* fail. A
/// hand-written "these nine controls are greyed" would repeat
/// that mistake in a new place — it cannot see site ten.
///
/// So this scans for shapes rather than listing controls: every
/// editor with an enable toggle must still carry a gate keyed on
/// that toggle, present the required number of times.
///
/// The companion half — no Settings view REMOVES a control with
/// `if <flag> { … }` — moved to `GreyOutHidingTests` when the
/// count field pushed this file to the 350-line ceiling.
///
/// Deliberate exceptions are listed with their reason and are
/// fail-shut: a new one is a conscious edit.
@Suite("Grey, don't hide")
struct GreyOutParityTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Files that must contain a `GreyOut` gate, with the
    /// predicate each one's block gate must be keyed on. These
    /// are the editors whose whole body configures something a
    /// switch can turn off — the #520 class.
    /// Each editor's block gate, as the EXACT expression it must
    /// still contain — not a bare identifier.
    ///
    /// The first cut of this list used needles like `"enabled"`,
    /// which the #520 review showed were satisfied by unrelated
    /// pre-existing code (`space_bar.enabled`, `isOn:
    /// $visual.enabled`): five of nine gates could be deleted
    /// outright with the suite still green. A needle that cannot
    /// fail is worse than no needle, because it reads like
    /// coverage.
    ///
    /// `count` is how many times the expression must occur, and
    /// it exists for the same reason `GreyOutAnchorTests` grew
    /// one: a file gating TWO rows with one expression keeps a
    /// bare `contains` green with either of the pair deleted.
    /// That shipped here — the App Bar's Gap-indicator gate
    /// guards both Highlight and Active item with an identical
    /// call, and a guard-prover run deleting only Highlight's
    /// left the suite green while the swatch stayed editable
    /// with nothing to tint (#678 Phase 3).
    private let gatedEditors: [(file: String, gate: String, count: Int)] = [
        // The block gate now resolves through `GapsBordersGates`
        // (#678 Phase 3): the needle is the resolver-driven wrap
        // on the controls block, not the old inline predicate.
        (
            "FocusBorderEditor.swift",
            "GreyOut(active: blockReason != nil",
            1
        ),
        // The two census-rendered bar cards (#678 Phase 2)
        // carry their container gates per row, resolved from
        // the census — the needle is the per-row wrap that
        // honors `exemptFromContainerGate`.
        (
            "SpaceBarCard.swift",
            "active: !allows",
            1
        ),
        (
            "AppBarCard.swift",
            "active: !allows",
            1
        ),
        // Each drag column's outer gate resolves through
        // `GapsBordersGates` (#678 Phase 3) — the enabled reason
        // wraps border, width, alignment and fill.
        (
            "DragVisualsEditor.swift",
            "active: enabledReason != nil",
            1
        ),
        // `StickyMarkEditor` is deliberately absent: its coverage
        // guard was dropped in #678 Phase 3, the mark being what
        // survives the Space Bar rather than what depends on it.
        // The opposite invariant — that no gate returns — is
        // `StickyMarkUngatedTests`.
        //
        // The Desktop bindings grey is the card's OWN since #678
        // turn 13a — the predicate came from the caller before,
        // and a resolver the caller feeds is a resolver two
        // files can disagree about. One needle now, on the
        // dimmed subtree: the reason is the resolver's (pinned
        // by `ProfilesGateWiringTests`) and this pins that the
        // reason actually dims the rows. The gate still stops
        // short of the card header and the inline note, so both
        // the disclosure label and the "Open Desktop & Dock"
        // button stay live under it (#527).
        (
            "NativeSpacesGroup.swift",
            "GreyOut(active: reason != nil",
            1
        ),
        // The per-space grid and track override greys now resolve
        // through `SpacesGates` (#678 Phase 3, turn 8): all three
        // GreyOut blocks (fill-empty, the Columns/Rows pair, the
        // track limit) wrap on a resolver call rather than an
        // inline `resolvedGrid`/`resolvedTrack` predicate. The
        // count pins that every one still greys — dropping any
        // one would leave a control live with nothing to act on.
        // `SpacesGateWiringTests` holds WHICH gate each consults.
        (
            "SpaceOverrideRows+ModeRows.swift",
            "active: gates.inertReason(",
            3
        ),
        // Advanced Colours (#678 Phase 3), which replaced the
        // interim colour cards.
        //
        // The first pins the WIRING: each row must actually
        // apply the resolved container gate. The gate's own
        // logic — that an exemption escapes the container grey
        // and nothing else — used to live inline here as a
        // shape pin whose green was not coverage; it is now a
        // pure function with a behavioural test
        // (`ColorsGateTests`,
        // `exemptionEscapesOnlyTheContainerGate`), so this
        // needle no longer has to stand in for it.
        //
        // The second IS behavioural: without it a row gate
        // fires alongside its container gate and the hover
        // names a row-specific reason that fixing would not
        // un-grey anything.
        (
            "BarColorCards.swift",
            "GreyOut(active: gate.containerGrey",
            1
        ),
        (
            "AdvancedColorRow.swift",
            "GreyOut(active: ownPredicateLive && inert",
            1
        ),
        // The one row-gate predicate the census cannot express:
        // the Gap indicator hides the active item outright, so
        // neither ink is painted.
        (
            "AdvancedColorRow+Bars.swift",
            "gates.bars.gapOnly",
            2
        ),
        // Not a GreyOut site — a plain `.disabled` with its own
        // reason-bearing help — but the same convention, and
        // the same failure if it is dropped: Apply would switch
        // the live layout while the header promises it won't
        // (#518). The predicate is the resolver's since #678
        // turn 13a, so the needle is the `.disabled` reading
        // ITS reason rather than a hand-rolled comparison.
        // Moved with Apply itself in #859 — see
        // `ProfilesGateWiringTests` for why the card is
        // its own widget now.
        ("PresetCard.swift", ".disabled(reason != nil)", 1),
    ]

    @Test("every gated editor still greys off its own switch")
    func gatedEditorsCarryTheirGate() throws {
        let files = try SourceScan.swiftSources(under: settingsDir)
        for (name, gate, count) in gatedEditors {
            let file = try #require(
                files.first { $0.lastPathComponent == name },
                "gated editor file is gone: \(name)"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let found =
                source.components(separatedBy: gate).count - 1
            // EXACT, not a floor. `>=` lets an expression that
            // later gains a third occurrence regain slack — one
            // of three could then be deleted green, which is the
            // hole the count field was added to close. Every
            // entry matches exactly today, so a gate gaining an
            // occurrence is a conscious edit here too.
            #expect(
                found == count,
                Comment(
                    rawValue:
                        "\(name) has \(found) of \(count) gate(s) "
                        + "`\(gate)` — a control with no effect "
                        + "must be greyed, never left live (#171)"
                )
            )
        }
    }

    // Two sibling suites, split off before this file reached
    // the 350-line ceiling (§5, split early): the #527
    // block-gate help-anchor guard is `GreyOutAnchorTests`, and
    // the hide-instead-of-dim scan is `GreyOutHidingTests`.

    /// The real invariant, tested on the primitive instead of
    /// on every call site: `GreyOut` dims ONCE however deeply it
    /// nests. The previous shape of this test asserted that each
    /// inner gate carried a hand-written `blockIsOn &&`
    /// conjunction — which is exactly the "one more place to
    /// forget" the #520 review then caught being forgotten (a
    /// modifier applied twice, and two `AutoGatedGroup`s dimming
    /// to 0.25 from the shipping defaults).
    ///
    /// The environment flag makes it unrepresentable instead, so
    /// what needs pinning is the primitive's own wiring.
    @Test("the grey treatment dims once, however it nests")
    func greyOutDimsOnce() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "AutoGatedGroup.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        // Dims only when no ancestor already did.
        #expect(
            source.contains("active && !alreadyDimmed ? 0.5 : 1")
        )
        // …and publishes the fact to everything below.
        #expect(source.contains("alreadyDimmed || active"))
        // Disabling is unconditional: the control is inert
        // whether or not an ancestor already dimmed it.
        #expect(source.contains(".disabled(active)"))

        // The override chrome dims through the same flag, so an
        // inheriting row inside a gated block cannot compound.
        let chrome = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "SpaceOverrides/OverrideControls.swift"
            )
        let chromeSource = SourceScan.stripComments(
            try String(contentsOf: chrome, encoding: .utf8)
        )
        #expect(chromeSource.contains("isInsideGreyOut"))
        #expect(chromeSource.contains("!alreadyDimmed"))
    }

    /// No control may carry the treatment twice — that compounds
    /// to 0.25 through the one path the environment flag cannot
    /// see, since both modifiers sit at the same depth. Shipped
    /// once in this very sweep before review caught it.
    @Test("no view applies the grey treatment twice in a row")
    func noDoubledGreyOutModifier() throws {
        for file in try SourceScan.swiftSources(
            under: settingsDir
        ) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let lines = source.split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            for (index, line) in lines.enumerated()
            where index > 0 {
                let previous = lines[index - 1]
                let doubled =
                    line.contains(".modifier(GreyOut(")
                    && previous.contains(".modifier(GreyOut(")
                #expect(
                    !doubled,
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent):"
                            + "\(index + 1) applies GreyOut "
                            + "twice — that dims to 0.25"
                    )
                )
            }
        }
    }
}
