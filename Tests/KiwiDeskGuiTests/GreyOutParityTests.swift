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
/// So this scans for the shapes that *hide* instead:
///
/// 1. Every editor with an enable toggle greys its dependent
///    block (checked by presence of a gate keyed on the toggle).
/// 2. No Settings view removes a control with `if <flag> { … }`
///    where the flag is one of the known visibility predicates —
///    the shape that produced findings A7 and A8.
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
    private let gatedEditors: [(file: String, gate: String)] = [
        (
            "FocusBorderEditor.swift",
            "active: !style.wrappedValue.enabled"
        ),
        ("SpaceBarGroups.swift", "GreyOut(active: !enabled"),
        ("AppBarGroups.swift", "GreyOut(active: !anyBarShown"),
        ("DragVisualsEditor.swift", "active: !visual.enabled"),
        ("StickyIndicatorEditor.swift", "active: !spaceBarOn"),
        ("AppBarLayoutGroup.swift", "active: !bar.enabled"),
        (
            "ProfilesSection.swift",
            "active: model.editingStoredProfile"
        ),
        (
            "SpaceOverrideRows+ModeRows.swift",
            "active: g.resolvedGrid(for: space).autoSize"
        ),
        ("AppBarGroups+Colors.swift", "active: gapOnly"),
        // Not a GreyOut site — a plain `.disabled` with its own
        // reason-bearing help — but the same convention, and
        // the same failure if it is dropped: Apply would switch
        // the live layout while the header promises it won't
        // (#518).
        ("PresetsSection.swift", "model.editingStoredProfile"),
    ]

    @Test("every gated editor still greys off its own switch")
    func gatedEditorsCarryTheirGate() throws {
        let files = try SourceScan.swiftSources(under: settingsDir)
        for (name, gate) in gatedEditors {
            let file = try #require(
                files.first { $0.lastPathComponent == name },
                "gated editor file is gone: \(name)"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                source.contains(gate),
                Comment(
                    rawValue:
                        "\(name) lost its gate "
                        + "`\(gate)` — a control with no effect "
                        + "must be greyed, never left live (#171)"
                )
            )
        }
    }

    /// The hiding shape, discovered rather than enumerated.
    /// `if <predicate> {` around settings content removes it from
    /// the tree, which loses the cue that the stored value is
    /// preserved (`docs/ui-patterns.md`). Findings A7
    /// (`if bar.enabled`) and A8 (`if !model.editingStoredProfile`)
    /// were both exactly this.
    private let hidingPredicates = [
        "if bar.enabled {",
        "if !model.editingStoredProfile {",
        "if model.editingStoredProfile {",
        "if style.wrappedValue.enabled {",
        "if visual.enabled {",
    ]

    /// Fail-shut exemptions, one line of reason each. The scan
    /// stays broad ON PURPOSE — narrowing the needles to the two
    /// shapes this sweep fixed would turn the lens back into a
    /// list, and site ten would be invisible again. So a NEW
    /// `if <predicate> {` in Settings fails here until someone
    /// states why it removes rather than dims.
    ///
    /// Every entry below was examined when the guard was
    /// written; all three predate #520 and none of them hides a
    /// control that exists in the other mode.
    private let hidingExempt: [String: String] = [
        // ADDS an explanatory banner in stored-profile mode.
        // Additive, so there is nothing being taken away.
        "ShortcutsSection.swift":
            "adds a banner; removes nothing",
        // Not a view at all — a `String?` computed property
        // choosing which status sentence to return.
        "ProfileHeader.swift":
            "String? branch, not a rendered control",
        // An either/or slot: every branch renders a control (or
        // EmptyView in raw-Lua mode, where a profile-copy verb
        // has no referent). Nothing is hidden that exists in the
        // other branch.
        "SettingsFooter.swift":
            "either/or slot; each mode renders its own verb",
    ]

    /// OS-capability gates are the one legitimate reason to
    /// remove rather than dim: a control for a rendering path
    /// this macOS cannot perform is not "off", it does not
    /// exist. Settled in #390.
    private let capabilityGate = "AppBarStyle.glassAvailable"

    @Test("no settings view hides a control it should grey")
    func noHidingPredicatesRemain() throws {
        var scanned = 0
        let files = try SourceScan.swiftSources(
            under: settingsDir
        )
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            let name = file.lastPathComponent
            if hidingExempt[name] != nil { continue }
            for shape in hidingPredicates {
                #expect(
                    !source.contains(shape),
                    Comment(
                        rawValue:
                            "\(name) hides a control with "
                            + "`\(shape)` — grey it instead "
                            + "(#171), or add it to hidingExempt "
                            + "with a stated reason"
                    )
                )
            }
        }
        // A scan over nothing passes vacuously.
        #expect(scanned > 40)
        // An exemption for a file that no longer exists is a
        // stale excuse quietly widening the net.
        let names = Set(files.map(\.lastPathComponent))
        for (file, reason) in hidingExempt {
            #expect(
                names.contains(file),
                Comment(
                    rawValue: "stale hiding exemption: \(file)"
                )
            )
            #expect(!reason.isEmpty)
        }
        #expect(!capabilityGate.isEmpty)
    }

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
                "Sources/KiwiDesk/Settings/Components/Bars/"
                    + "AppBarOverrideControls.swift"
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
