import Foundation
import Testing

@testable import KiwiDesk

/// The mode-gated chrome pairing (#760), in the idiom of
/// `MonitorsChromeWiringTests` / `PaletteShelfChromeTests`: the
/// container shapes draw BOTH stroke weights
/// (`SettingsTheme.containerStroke` and
/// `SettingsTheme.containerStrokeModeGated`) through one
/// ternary, the flag each site passes is its own offer
/// predicate evaluated at `.simple` — never a hand-negated
/// copy — and the reveal wash rides the title band beside the
/// same flag. `SettingsModeRevealTests` holds the timeline's
/// behaviour; this suite holds where the chrome lands.
@Suite("Mode-gated chrome")
struct ModeGatedChromeTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    private func squashed(_ path: String) throws -> String {
        let url = Self.root
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The one weight ternary, per container shape — the pair's
    /// two weights cannot drift apart while every drawer reads
    /// both through it.
    @Test("each container shape draws both weights")
    func containersDrawBothWeights() throws {
        let ternary =
            "lineWidth:modeGated"
            + "?SettingsTheme.containerStrokeModeGated"
            + ":SettingsTheme.containerStroke"
        for file in [
            "HomeCard.swift",
            "Components/Common/SettingsSection.swift",
            "Components/Common/SettingsDisclosure.swift",
        ] {
            #expect(
                try squashed(file).contains(ternary),
                Comment(
                    rawValue:
                        "\(file) lost the weight ternary — the "
                        + "mode-gated signal no longer draws "
                        + "there"
                )
            )
        }
    }

    /// The gated frame is the ACCENT at the shipped strength —
    /// the mode's own colour (amended ruling, on-device
    /// 2026-08-09) — and every shape reads the one opacity
    /// metric, so a retune moves all three frames together.
    /// The floors that strength must clear live in
    /// `ModeGatedFrameSeparationTests`, derived from the
    /// tokens.
    @Test("the gated frame draws the accent at one strength")
    func gatedFrameDrawsTheAccent() throws {
        let arm =
            "SettingsTheme.accent.opacity("
            + "SettingsTheme.modeGatedStrokeOpacity)"
        for file in [
            "HomeCard.swift",
            "Components/Common/SettingsSection.swift",
            "Components/Common/SettingsDisclosure.swift",
        ] {
            #expect(
                try squashed(file).contains(
                    "modeGated?\(arm):SettingsTheme.hairline"
                ),
                Comment(rawValue: file)
            )
        }
    }

    /// VoiceOver's copy of the durable answer: a gated card
    /// appends the segment's own label to its value, through
    /// the shared joiner frame — the spoken word and the
    /// switch cannot drift apart.
    @Test("a gated card voices Power User")
    func gatedCardVoicesTheMode() throws {
        #expect(
            try squashed("HomeCard.swift").contains(
                "guardmodeGatedelse{returnbase}"
            )
        )
        #expect(
            try squashed("HomeCard.swift").contains(
                "base,L(\"mode.power_user\",\"PowerUser\")"
            )
        )
    }

    /// The flag is THE offer predicate at `.simple`. A
    /// hand-negated twin beside the stroke is the drift the
    /// one-predicate rule exists to prevent — it is how the
    /// weight would silently disagree with presence on the
    /// Monitors computed promotion.
    @Test("the Home card's flag is the offer predicate")
    func homeCardFlagIsTheOfferPredicate() throws {
        #expect(
            try squashed("HomeCard.swift").contains(
                "!HomeCardOrder.isOffered("
                    + "destination,mode:.simple,"
            )
        )
    }

    /// The mode-gated set is DERIVED, not hand-listed: any
    /// Settings file whose offer consults `.powerUser` is a
    /// member, and each one either threads `modeGated` to a
    /// container shape or is enumerated here with the reason it
    /// stays unmarked — the one copy of who may
    /// (`borderedExempt`'s shape). `SpaceOverrideOffer` is the
    /// proof this scan earns its keep: it predates the
    /// vocabulary and shipped unmarked with every needle green.
    ///
    /// Two stated limits, so they read as granularity rather
    /// than coverage: membership needles the SPELLING
    /// `== .powerUser` (a predicate respelled `!= .simple` or
    /// `case .powerUser` evades it), and `contains("modeGated")`
    /// proves a member acknowledges the vocabulary, not that it
    /// wires the flag — the wiring stays hand-needled per site
    /// by the two tests below.
    private static let unmarked: [String: String] = [
        // The flip machinery itself, not an offer.
        "SettingsModel+Mode.swift":
            "declares the flip; gates nothing",
        // The shared predicate's implementation — every Home
        // card threads modeGated from it by construction.
        "HomeCardOrder.swift":
            "the predicate; HomeCard threads the signal",
        // A per-row CONTROL offer: no container border to
        // weight, and washing a dozen sibling rows at once is
        // the shouting the three-places reveal avoids
        // (ui-designer + architect review, 2026-08-09) — the
        // cells appear plainly.
        "SpaceOverrideOffer.swift":
            "per-row control offer; no container to mark",
    ]

    @Test("a .powerUser offer is marked or enumerated")
    func modeGatedSetIsDerived() throws {
        let dir = Self.root
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        var members: [String] = []
        var violations: [String] = []
        for file in try SourceScan.swiftSources(under: dir) {
            let source = SourceScan.stripComments(
                (try? String(contentsOf: file, encoding: .utf8))
                    ?? ""
            )
            guard source.contains("== .powerUser") else {
                continue
            }
            let name = file.lastPathComponent
            members.append(name)
            if !source.contains("modeGated"),
                Self.unmarked[name] == nil
            {
                violations.append(name)
            }
        }
        // A scan that found no members read the wrong tree.
        #expect(members.count >= 5)
        #expect(
            violations.isEmpty,
            Comment(
                rawValue:
                    "a .powerUser offer neither threads "
                    + "modeGated nor argues its exemption: "
                    + violations.sorted().joined(separator: ", ")
            )
        )
        for (name, reason) in Self.unmarked {
            #expect(
                members.contains(name),
                Comment(
                    rawValue:
                        "stale exemption: \(name) no longer "
                        + "consults .powerUser"
                )
            )
            #expect(!reason.isEmpty, Comment(rawValue: name))
        }
    }

    @Test("in-area flags derive from their own offer predicate")
    func inAreaFlagsDeriveFromTheirOffer() throws {
        #expect(
            try squashed("Sections/LayersCard.swift").contains(
                "modeGated:Bool{!offered(in:.simple)}"
            )
        )
        #expect(
            try squashed("Sections/ShortcutsSection.swift")
                .contains(
                    "modeGated:!offersAdvancedDrawer(in:.simple)"
                )
        )
    }

    /// The wash paints the title band alone — a whole-card wash
    /// would tint a card's live preview or a drawer's expanded
    /// interior through the accent, misrepresenting what they
    /// render (ui-designer, 2026-08-09).
    @Test("the wash rides the title band, never the whole card")
    func washRidesTheTitleBand() throws {
        #expect(
            try squashed("HomeCard.swift").contains(
                "titleRow.modeRevealWash(modeGated)"
            )
        )
        #expect(
            try squashed(
                "Components/Common/SettingsSection.swift"
            ).contains(
                ".searchFlashHeader(control)"
                    + ".modeRevealWash(modeGated)"
            )
        )
        // The String-init branch too — unreached today, which
        // is exactly when a branch goes dead unnoticed (the
        // wiring-needle lesson): a computed-title section that
        // ever takes modeGated must wash like its catalog twin.
        #expect(
            try squashed(
                "Components/Common/SettingsSection.swift"
            ).contains(
                "else{header.modeRevealWash(modeGated)}"
            )
        )
        #expect(
            try squashed(
                "Components/Common/SettingsDisclosure.swift"
            ).contains(
                ".searchFlashHeader(control)"
                    + ".modeRevealWash(modeGated)"
            )
        )
    }

    /// The house Reduce Motion split, in both moving parts: the
    /// wash drops only its cross-fade (the affordance stays),
    /// and the timeline's hold absorbs the dropped fade so the
    /// accessibility branch gets the same ≈1.2 s cue.
    @Test("Reduce Motion drops the fade, never the affordance")
    func reduceMotionSplit() throws {
        #expect(
            try squashed("SettingsModeReveal.swift").contains(
                "guard!reduceMotion,!washedelse{returnnil}"
            )
        )
        #expect(
            try squashed("SettingsModel+Mode.swift").contains(
                "+(reduceMotion?SettingsReveal.fade:0)"
            )
        )
    }

    /// The flip's reflow animates on the mode value and stands
    /// down under Reduce Motion — insertion in, plain fade out,
    /// highlight neither. Two mounts: Home's grid, and the
    /// detail pane for the area the user is standing in.
    @Test("the grid reflow keys on the mode and splits on RM")
    func gridReflowSplit() throws {
        let needle =
            ".animation(reduceMotion?nil:.easeOut("
            + "duration:SettingsReveal.scroll),"
            + "value:model.settingsMode)"
        #expect(try squashed("HomeScreen.swift").contains(needle))
        #expect(
            try squashed("SettingsView+Detail.swift").contains(
                needle
            )
        )
    }

    /// The implicit promotion stays on `setSettingsMode` — the
    /// wash's entry point is the segment alone, so a search
    /// landing never fires two accent washes at once. Scanned
    /// over the WHOLE GUI target, not one file or directory:
    /// `flipSettingsMode` is internal to `KiwiDesk`, so the
    /// likely second entry (a menu-bar or onboarding surface
    /// with a model handle) lives outside `Settings/` and must
    /// red here rather than become the forgotten second wiring
    /// point.
    @Test("the segment is the flip's one caller")
    func promotionStaysSilent() throws {
        let view = try squashed("SettingsView.swift")
        #expect(
            view.contains("model.setSettingsMode(.powerUser)")
        )
        let dir = Self.root
            .appendingPathComponent("Sources/KiwiDesk")
        var callers: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: dir) {
            let source = SourceScan.stripComments(
                (try? String(contentsOf: file, encoding: .utf8))
                    ?? ""
            )
            scanned += 1
            if source.contains("flipSettingsMode") {
                callers.append(file.lastPathComponent)
            }
        }
        // A scan that read nothing would pass having read
        // nothing (#635).
        #expect(scanned > 50)
        #expect(
            Set(callers) == [
                // The declaration…
                "SettingsModel+Mode.swift",
                // …and the segment, its one caller.
                "SettingsHeaderBar.swift",
            ],
            Comment(
                rawValue:
                    "flipSettingsMode reached from: "
                    + callers.sorted().joined(separator: ", ")
            )
        )
    }
}
