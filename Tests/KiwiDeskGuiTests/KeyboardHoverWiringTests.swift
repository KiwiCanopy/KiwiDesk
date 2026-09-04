import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The wiring half of the hover slot (#798). The reading being
/// right buys nothing while the panel renders it from a second
/// fold, announces it twice, or reads the disabled set from an
/// environment that cannot reach it.
@Suite("Keyboard hover wiring")
struct KeyboardHoverWiringTests {
    /// The panel is TWO files since the slot outgrew one
    /// (§2.1), and a needle pointed at the wrong half passes
    /// for having found nothing — so the subject is read whole,
    /// and the file list is asserted non-empty.
    private static let panelFiles = [
        "KeyboardPreviewPanel.swift",
        "KeyboardPreviewPanel+Slot.swift",
    ]

    private static func source(_ file: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/\(file)"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    private static func panelSource() throws -> String {
        var joined = ""
        for file in panelFiles {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/"
                        + "Keybindings/\(file)"
                )
            joined += SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
        }
        return joined.split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The blocker this feature would have shipped: the panel is
    /// the section's SIBLING, so `\.disabledSystemShortcuts` —
    /// wired inside `ShortcutsSection`'s own body — resolves to
    /// the key's EMPTY default here. Six chords ship disabled,
    /// and `⌃⌥⌘8` is both a seeded default and Invert Colors, so
    /// the strip would tell a large share of installs that a
    /// working shortcut is dead.
    @Test("the disabled set is read live, not from a sibling's environment")
    func disabledSetIsReadAtThePanel() throws {
        let panel = try Self.panelSource()
        // Vacuity: an unreadable half is an empty needle set.
        #expect(!panel.isEmpty)
        // CONTIGUOUS from the capture to the builder it feeds:
        // a whole-file substring was satisfied by a plausible
        // sibling read elsewhere in the file while the builder
        // took `disabled: []` — green, and every dormant chord
        // narrated as dead (guard-prover, 2026-09-05). The
        // geometry between the two is glue holding the needle
        // contiguous, not an assertion (tests.md).
        // CONTIGUOUS from the capture to the builder it feeds:
        // a whole-file substring was satisfied by a plausible
        // sibling read elsewhere in the file while the builder
        // took `disabled: []` — green, and every dormant chord
        // narrated as dead (guard-prover, 2026-09-05). What sits
        // between the two is glue holding the needle contiguous,
        // not an assertion (tests.md).
        let carried =
            "letdisabled=model.disabledSystemShortcuts()"
            + "letlayers=shownletscope=liveScope"
            + "letselection=selectedletconfig=model.config"
            + "return{codeinKeyboardHoverReading.of("
            + "code,in:layers,scope:scope,selected:selection,"
            + "config:config,disabled:disabled)}"
        #expect(
            panel.contains(carried),
            Comment(
                rawValue: "the reader no longer carries the live "
                    + "read into the builder it feeds"
            )
        )
    }

    /// One builder, two channels. A second fold in the view is
    /// how the strip comes to name an action on a key the fill
    /// draws as free.
    @Test("both channels read the one hover builder")
    func oneBuilderFeedsBothChannels() throws {
        let panel = try Self.panelSource()
        #expect(
            panel.occurrences(of: "KeyboardHoverReading.of(") == 1
        )
        // …the drawn half, and the spoken half, both through
        // the ONE reader closure — which is also what holds the
        // live preference read to once per panel render.
        #expect(panel.contains("liveReading(hovered).lines"))
        #expect(panel.contains("read($0).lines"))
        #expect(panel.contains("conflictDetail:conflictDetail"))
        #expect(
            panel.occurrences(
                of: "model.disabledSystemShortcuts()"
            ) == 1,
            Comment(
                rawValue: "one live read per panel render — a "
                    + "second call is a preference sweep per "
                    + "ringed key, per body evaluation"
            )
        )
    }

    /// The slot announces the TALLY under the pointer as well:
    /// the board already describes itself, and a hover reading
    /// read beside it is the caption-twice failure.
    @Test("the slot stands down on the spoken channel")
    func slotAnnouncesTheTally() throws {
        let panel = try Self.panelSource()
        #expect(
            panel.contains(
                ".accessibilityElement(children:.ignore)"
                    + ".accessibilityLabel(tallyText)"
            )
        )
    }

    /// A cap rebuilt under the pointer never delivers
    /// `onHover(false)` — the `NSCursor` push/pop class — and
    /// both of these rebuild the board.
    @Test("a rebuilt board drops its stale hover")
    func staleHoverIsCleared() throws {
        let panel = try Self.panelSource()
        #expect(
            panel.contains(
                ".onChange(of:liveScope){_,_inhovered=nil}"
            )
        )
        #expect(
            panel.contains(
                "shortcutsLayerSelection){_,_inhovered=nil}"
            )
        )
    }

    /// The tally has ONE home now that the slot renders it in
    /// both states — a second copy is two sentences that can
    /// disagree about the same count.
    @Test("the tally sentence is written once")
    func tallyHasOneHome() throws {
        let panel = try Self.panelSource()
        #expect(panel.occurrences(of: "keyboard.tally") == 1)
    }

    /// The hover CHANNEL, which nothing watched: `onHover` is an
    /// optional closure with a nil default at both hops, so
    /// deleting either wiring compiles silently and the slot
    /// never leaves the tally — the feature dead on screen with
    /// every suite green (guard-prover, 2026-09-05).
    ///
    /// tests.md's inverted-seam rule: a seam that defaults INERT
    /// and is opted into owes a TWO-SIDED guard, so losing the
    /// wiring reds as loudly as duplicating it.
    @Test("the hover channel is wired at every hop")
    func hoverChannelIsWired() throws {
        let panel = try Self.panelSource()
        #expect(panel.contains("onHover:{hovered=$0}"))
        #expect(panel.occurrences(of: "onHover:{hovered=$0}") == 1)

        let spoken = try Self.source("KeyboardBoardSpoken.swift")
        #expect(spoken.contains("onHover:onHover"))

        // …and the POLARITY at the cap: reporting the code on
        // the way out strands the slot on the last key touched,
        // which is the `NSCursor` class this clears.
        let board = try Self.source("KeyboardBoard.swift")
        #expect(
            board.contains("onHover(inside?key.code:nil)"),
            Comment(
                rawValue: "a cap that never reports leaving "
                    + "strands the reading on it"
            )
        )
    }
}
