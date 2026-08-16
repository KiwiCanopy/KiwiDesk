import Foundation
import Testing

@testable import KiwiDesk

/// The Profiles views are wired to the gate resolver (#678 Phase
/// 3, turn 13a), split from the behaviour suite so neither file
/// crosses the size ceiling.
///
/// General shipped a round-1 cut whose resolver was built only in
/// tests while the views re-derived each predicate and re-authored
/// each sentence inline; the census gate and the on-screen grey
/// could then drift with every gate test still green. This is the
/// wiring half — the behaviour half is `ProfilesGateTests`.
///
/// SCOPE: by explicit path, one entry per GATE rather than per
/// file. `NativeSpacesGroup` resolves one gate that has two
/// reasons, and a file-level "touches the resolver somewhere"
/// check would pass while one of them went hand-rolled — the very
/// drift this guard exists to catch. A future gated row in this
/// area owes both its resolver consult AND a `consults` entry
/// naming the file that draws it, in the same change;
/// `everyGatedRowIsResolved` forces the resolver half, and
/// nothing but this map forces the view half.
@Suite("Profiles gate wiring")
struct ProfilesGateWiringTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// `path` is relative to `Settings/`, so the map below can
    /// name files in either `Components/Profiles/` or
    /// `Sections/`.
    private func read(_ path: String) throws -> String {
        try String(
            contentsOf: settingsDir.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    @Test("each gate is wired to the resolver, not a copy")
    func rowsConsultTheResolver() throws {
        // Whitespace-free source, so a needle survives the
        // formatter wrapping an `inertReason(for:)` call across
        // lines.
        func squashed(_ name: String) throws -> String {
            SourceScan.stripComments(try read(name))
                .split(whereSeparator: \.isWhitespace)
                .joined()
        }
        let consults: [String: [String]] = [
            "Components/Profiles/NativeSpacesGroup.swift": [
                "inertReason(for:.profiles(.profileBindings))"
            ],
            "Sections/PresetsSection.swift": [
                "inertReason(for:.profiles(.presetsApply))"
            ],
        ]
        for (name, needles) in consults {
            let source = try squashed(name)
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) no longer wires `\(needle)` "
                            + "to the gate resolver — that gate "
                            + "went hand-rolled"
                    )
                )
            }
            #expect(
                source.contains("ProfilesGateHelp.sentence"),
                Comment(
                    rawValue:
                        "\(name) does not read ProfilesGateHelp "
                        + "for its inert caption"
                )
            )
        }
        try sentencesAreAuthoredOnce(Array(consults.keys))
    }

    /// The three bespoke containers derive their instances from
    /// `ProfilesFamilyRows`, not from re-derivations of their
    /// own.
    ///
    /// Without this the family seam is a data structure that
    /// exists only for its own guard — the dead-resolver trap
    /// General shipped, one level over: `familiesExpand` and
    /// `instanceCounts` would assert over lists the screen never
    /// sees, and the real derivations would sit inline in the
    /// views where nothing holds them to the census. Both
    /// reviewers found that shape in this area's first cut.
    ///
    /// Stated limit: this pins that each view CALLS the seam, not
    /// that it renders what it gets back.
    @Test("the bespoke containers consult the family seam")
    func viewsConsultTheFamilySeam() throws {
        func squashed(_ name: String) throws -> String {
            SourceScan.stripComments(try read(name))
                .split(whereSeparator: \.isWhitespace)
                .joined()
        }
        let consults: [String: [String]] = [
            "Sections/ProfilesSection.swift": [
                "ProfilesFamilyRows.orderedProfiles("
            ],
            "Components/Profiles/NativeSpacesGroup.swift": [
                "ProfilesFamilyRows.desktops("
            ],
            "Sections/PresetsSection.swift": [
                "ProfilesFamilyRows.presets(forScreens:",
                "ProfilesFamilyRows.presets(excludingScreens:",
                // The APPLIABLE cards get the live screens; the
                // drawer gets nil. A card resolving an unlisted
                // mode without the hardware names a layout Apply
                // will not produce, and every assertion over the
                // types passes because both sides are then handed
                // the same shape by the test (code review,
                // 2026-08-11).
                "presetRow($0,sizes:liveSizes)",
                "presetRow($0,sizes:nil)",
            ],
            "Components/Profiles/PresetScreenCard.swift": [
                // …and the card must actually spend it.
                "on:shape(of:screen)",
                "ScreenClass.of(liveSizes[screen])",
                // The outline is a Shape, so `.help` alone
                // reaches no screen reader — the sentence that
                // names the main display only exists for a
                // non-visual reader through this pair, and
                // deleting both modifiers is silent in every
                // other guard. Headless can prove the
                // construction is present, never that VoiceOver
                // reaches it; that half is an Accessibility
                // Inspector pass (gui.md ▸ the keyboard path).
                ".accessibilityElement()",
                ".accessibilityLabel(screenHelp(screen))",
            ],
        ]
        for (name, needles) in consults {
            let source = try squashed(name)
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) no longer derives its rows "
                            + "from `\(needle)` — that container "
                            + "re-derives its instances inline, "
                            + "and the census guards over the "
                            + "seam stop watching the screen"
                    )
                )
            }
        }
    }

    /// The "Which profile loads" card reads the whole-rule
    /// verdict, and asks the profile matcher nothing.
    ///
    /// This is the seam the card's first cut got wrong: it
    /// called `ProfileManager.match`, which answers the DISPLAY
    /// half only — a native-Space binding outranks matching —
    /// so with a Desktop bound the card named one profile while
    /// another was on screen. `KiwiCore.profileVerdict` carries
    /// the whole precedence; a call site that reaches past it to
    /// `match` is that defect returning, and no behavioural test
    /// over the verdict can see it.
    @Test("the which-loads card reads the whole-rule verdict")
    func whichLoadsReadsTheVerdict() throws {
        let name = "Sections/ProfilesSection+WhichLoads.swift"
        let squashed = SourceScan.stripComments(try read(name))
            .split(whereSeparator: \.isWhitespace)
            .joined()
        // The snapshot carries the screen count WITH the verdict,
        // so the needle is the whole value: reading a live count
        // beside a snapshotted verdict is what let the sentence
        // be assembled from two moments.
        #expect(
            squashed.contains("model.profileResolution"),
            Comment(
                rawValue:
                    "\(name) no longer reads the model's "
                    + "resolution snapshot"
            )
        )
        #expect(
            !squashed.contains("model.displays.count"),
            Comment(
                rawValue:
                    "\(name) reads the display count live beside "
                    + "a snapshotted verdict — one sentence, two "
                    + "moments"
            )
        )
        #expect(
            !squashed.contains(".match("),
            Comment(
                rawValue:
                    "\(name) asks the profile matcher directly — "
                    + "that answers the display half of the rule "
                    + "only, and a bound Desktop outranks it"
            )
        )
        // Nor may it scan the profile directory itself: the
        // verdict costs a decode per profile and belongs to the
        // refresh, never to a body pass.
        #expect(
            !squashed.contains("core.profiles"),
            Comment(
                rawValue:
                    "\(name) queries Core per render — the "
                    + "verdict is snapshotted by refreshProfiles"
            )
        )
    }

    /// Every gate sentence is authored ONCE, in the help enum; a
    /// row that re-authors one is the duplication that let
    /// General describe one status two ways.
    ///
    /// Stated limit: this reads the NAMED files only, so a gate
    /// sentence re-authored anywhere else under `Settings/` is
    /// invisible to it. A new file in this area joins the list.
    /// It also reads raw source including comments, so a comment
    /// quoting a key reds it — fail-closed, and cheap to fix.
    private func sentencesAreAuthoredOnce(
        _ consulting: [String]
    ) throws {
        let help = try read(
            "Components/Profiles/ProfilesGates.swift"
        )
        let nonAuthors =
            consulting + [
                "Sections/ProfilesSection.swift",
                "Sections/ProfilesSection+WhichLoads.swift",
                "Sections/ProfilesSection+RowActions.swift",
                // The rest of the extension family, added when
                // +RowActions exposed the list as half-swept
                // (review, 2026-08-16): the docstring above says
                // a new file in this area joins the list, and
                // three that predate it never had. A gate
                // sentence re-authored in any of them was
                // invisible to this guard.
                "Sections/ProfilesSection+Broken.swift",
                "Sections/ProfilesSection+Rename.swift",
                "Sections/ProfilesSection+Subtitle.swift",
            ]
        for key in [
            "profiles.native_spaces.live_only",
            "native_spaces.separate_warning",
            "presets.editing_stored",
            "presets.needs_screens",
        ] {
            #expect(
                help.contains(key),
                Comment(rawValue: "ProfilesGateHelp lost \(key)")
            )
            for name in nonAuthors {
                #expect(
                    !(try read(name)).contains(key),
                    Comment(
                        rawValue:
                            "\(name) re-authors \(key) — it must "
                            + "come from ProfilesGateHelp"
                    )
                )
            }
        }
    }
}
