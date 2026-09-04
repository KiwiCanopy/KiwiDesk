import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The keyboard board's spoken form (#812): one sentence per
/// state, read from the census's own predicates and in the
/// board's own order, and the panel mounting that form rather
/// than the bare board.
///
/// Locale-pinned per body (tests.md): the sentences are `L()`
/// frames and the list joiner is the platform's.
@MainActor
struct KeyboardBoardSpokenTests {
    private typealias Layer = KeyboardCensus.ModifierLayer

    /// Two rows, letter codes in matrix order; 49 is Space.
    private let rows: [[KeyboardMatrix.Key]] = [
        [.init(12), .init(13), .init(14)],  // Q W E
        [.init(49, 4), .init(nil, legend: "⌘")],
    ]

    /// Injected glyphs, so no assertion reaches the host's
    /// input source: a letter resolved through `UCKeyTranslate`
    /// is "A" on AZERTY where this fixture says "Q", and the
    /// suite would red with no defect (tests.md ▸ injected
    /// seams; code review 2026-08-24). 49 is absent so Space
    /// takes the localized functional word, as on device.
    private let glyphs: [UInt32: String] = [
        12: "q", 13: "w", 14: "e",
    ]

    private func glyph(_ code: UInt32) -> String? { glyphs[code] }

    @Test("keys land in the bucket the cap draws them in")
    func bucketsFollowTheCaps() {
        LocalizationManager.shared.select("en")
        // W bound, Q colliding, Space macOS's. Space used to be
        // BOUND here, on a comment reading "⌃⌥ reserves nothing
        // under macOS" — true until #1094 added ⌃⌥space (next
        // input source) to the map. Leaving it unclaimed is the
        // better fixture anyway: all three buckets now carry a
        // key, where `reserved` was previously empty.
        let pair = Layer(modifiers: [.control, .option])
        let claims: [UInt32: [Layer]] = [13: [pair]]
        let buckets = KeyboardBoardSpoken.buckets(
            rows: rows,
            claims: claims,
            scope: .one(pair),
            conflicted: [12],
            glyph: glyph
        )
        #expect(buckets.bound == ["W"])
        #expect(buckets.conflict == ["Q"])
        #expect(buckets.reserved == ["space"])
    }

    @Test("a bound key over a macOS reservation is a conflict")
    func overwriteIsConflict() {
        // #740: the first line of the BODY, never `init` — the
        // bucket words are localized, so on a German host this
        // read "Leertaste" and the suite reddened for the
        // host's language rather than for a defect (observed
        // 2026-08-24, `AppleLanguages` = de-DE).
        LocalizationManager.shared.select("en")
        let command = Layer(modifiers: [.command])
        // ⌘Space is Spotlight's; binding it is the solid red
        // ring, the same word as an own-row collision. ⌘W stays
        // free, so it is macOS's.
        let buckets = KeyboardBoardSpoken.buckets(
            rows: rows,
            claims: [49: [command]],
            scope: .one(command),
            conflicted: [],
            glyph: glyph
        )
        #expect(buckets.bound == ["space"])
        #expect(buckets.conflict == ["space"])
        #expect(buckets.reserved.contains("W"))
        #expect(!buckets.reserved.contains("space"))
    }

    @Test("under All, reservations are not asserted")
    func allScopeReservesNothing() {
        LocalizationManager.shared.select("en")
        let buckets = KeyboardBoardSpoken.buckets(
            rows: rows,
            claims: [:],
            scope: .all,
            conflicted: [],
            glyph: glyph
        )
        #expect(buckets == .init())
    }

    @Test("the sentence speaks only the buckets that have keys")
    func sentenceOmitsEmptyBuckets() {
        LocalizationManager.shared.select("en")
        let empty = KeyboardBoardSpoken.sentence(
            buckets: .init(),
            scopeLabel: "All",
            layerLabel: nil,
            conflictDetail: []
        )
        #expect(
            empty == "Keyboard preview, showing All. No keys bound."
        )
        let full = KeyboardBoardSpoken.sentence(
            buckets: .init(
                bound: ["Q", "W"],
                reserved: ["space"],
                conflict: ["W"]
            ),
            scopeLabel: "⌘",
            layerLabel: nil,
            conflictDetail: []
        )
        #expect(full.hasPrefix("Keyboard preview, showing ⌘. Bound: Q"))
        #expect(full.contains("macOS owns: space."))
        #expect(full.hasSuffix("Conflict: W."))
    }

    /// The drawing moved to ONE keybinding layer (#1127), so the
    /// sentence moves with it: a board that changes under a
    /// strip click and never says which layer it changed to is
    /// the same defect a sighted reader has, with no caption to
    /// fall back on. Withheld while there is only one layer,
    /// where naming it is noise.
    @Test("the sentence names the layer it was taken over")
    func sentenceNamesTheLayer() {
        LocalizationManager.shared.select("en")
        let named = KeyboardBoardSpoken.sentence(
            buckets: .init(bound: ["Q"]),
            scopeLabel: "All",
            layerLabel: "media",
            conflictDetail: []
        )
        #expect(
            named == "Keyboard preview, showing All. In the "
                + "\u{201C}media\u{201D} layer. Bound: Q."
        )
        #expect(
            !KeyboardBoardSpoken.sentence(
                buckets: .init(bound: ["Q"]),
                scopeLabel: "All",
                layerLabel: nil,
                conflictDetail: []
            ).contains("layer")
        )
    }

    /// The clause the accessibility budget was spent on (#798):
    /// the ring says two bindings clash and cannot say WHICH
    /// two, so the spoken form names them. It was deletable at
    /// either hop with every suite green — this suite never
    /// passed the parameter, so its default blinded it by
    /// construction (guard-prover, 2026-09-05), which is why the
    /// parameter now has no default at all.
    @Test("the conflict clause carries the readings it was given")
    func conflictDetailReachesTheSentence() {
        LocalizationManager.shared.select("en")
        let said = KeyboardBoardSpoken.sentence(
            buckets: .init(bound: ["J"], conflict: ["J"]),
            scopeLabel: "⌃⌥",
            layerLabel: nil,
            conflictDetail: [
                "⌃⌥J — Focus left", "⌃⌥J — Swap left",
            ]
        )
        #expect(said.contains("Conflict: J."))
        #expect(said.hasSuffix("⌃⌥J — Focus left ⌃⌥J — Swap left"))
        // …and nothing is appended where the board rings none:
        // the clause rides the conflict bucket, not the board.
        let quiet = KeyboardBoardSpoken.sentence(
            buckets: .init(bound: ["J"]),
            scopeLabel: "⌃⌥",
            layerLabel: nil,
            conflictDetail: ["⌃⌥J — Focus left"]
        )
        #expect(!quiet.contains("Focus left"))
    }

    /// The two locale seams of the spoken form, pinned by
    /// needle because nothing else can hold them yet: the
    /// en-pinned fixtures cannot tell the localized functional
    /// word from its English wire-name fallback (they are
    /// byte-identical until the `keyboard.key.*` keys are
    /// translated), and no assertion may contain a joiner word
    /// without reading the host's locale (guard-prover,
    /// 2026-08-24 — both mutations were INERT against the
    /// behavioural tests). The needles red when either routing
    /// line is deleted; whether the words arrive localized is
    /// the translation round's to prove on device.
    @Test("the spoken form keeps its two locale seams")
    func localeSeamsAreWired() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/KeyboardBoardSpoken.swift"
                    ),
                encoding: .utf8
            )
        )
        // The localized word is consulted before the glyph.
        #expect(
            source.contains(
                "if let word = functionalWord(code) { return word }"
            )
        )
        // The joiner reads the APP's locale, never the class
        // method's `Locale.current`.
        #expect(source.contains("formatter.locale = Locale("))
        #expect(
            source.contains(
                "LocalizationManager.shared.effectiveLocale"
            )
        )
        #expect(
            !source.contains("ListFormatter.localizedString")
        )
    }

    /// The panel mounts the SPOKEN board and silences the legend
    /// the sentence replaces — pinned by needle, since the
    /// mounting is the only thing that makes the sentence reach
    /// a reader.
    @Test("the panel mounts the spoken board, not the bare one")
    func panelMountsTheSpokenBoard() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/KeyboardPreviewPanel.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(
            source.occurrences(of: "SpokenKeyboardBoard(") == 1
        )
        #expect(source.occurrences(of: "KeyboardBoard(") == 1)
        // …and hands it the layer, so the spoken form says what
        // the caps were counted over (#1127).
        #expect(source.contains("layerLabel: layerLabel"))
        #expect(
            source.contains("fillLegend.accessibilityHidden(true)")
        )
    }
}
