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
        #expect(
            panel.contains("disabled:model.disabledSystemShortcuts()")
        )
        #expect(
            !panel.contains("\\.disabledSystemShortcuts"),
            Comment(
                rawValue: "the panel cannot see the section's "
                    + "environment — it would answer the empty "
                    + "default and narrate dormant as dead"
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
        // …the drawn half, and the spoken half.
        #expect(panel.contains("hoverReading(hovered)"))
        #expect(panel.contains("hoverReading($0)?.lines"))
        #expect(panel.contains("conflictDetail:conflictDetail"))
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
}
