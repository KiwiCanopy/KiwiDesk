import Foundation
import Testing

@testable import KiwiDesk

/// The census answer to "does this greyed row owe its reason
/// inline?" (#815), checked against the rows that already draw
/// one.
///
/// That check is the whole point of deriving it rather than
/// listing it: a hand-kept register of which rows owe a sentence
/// is one more thing to forget, while a derivation that
/// reproduces every shipped instance on the day it lands is
/// checkable — and it answers for a row nobody has written yet.
///
/// Two earlier cuts of the derivation are recorded here because
/// each was wrong in a way the suite now pins. The first tested
/// the GATING row for `atRest` and so claimed the App Bar's
/// whole Show-more block owed inline sentences — two rows inside
/// one disclosure are adjacent when the reader sees them, which
/// is what `visibilityRank` compares. The second had no `remote`
/// channel and claimed every Advanced Colours row owed one,
/// against `docs/ui-patterns.md`, which routes a gate on another
/// destination to a live `?` naming where to go.
@Suite("Gate reason placement (#815)")
@MainActor
struct GateReasonPlacementTests {
    private func channel(
        _ key: SettingKey
    ) -> GateReasonPlacement.Channel? {
        GateReasonPlacement.channel(key) { $0.placement }
    }

    /// Exactly these rows, no others. A new gated row joining
    /// the set is a real answer — draw its reason — and one
    /// leaving it means an adjacency changed, which is equally
    /// worth reading.
    @Test("the derivation names the rows that owe a sentence")
    func owedRowsAreTheKnownSet() {
        let owed = SettingKey.allCases.filter {
            GateReasonPlacement.owesInlineReason($0) {
                $0.placement
            }
        }
        #expect(
            Set(owed) == [
                // Shipped inline before #815, and the reason the
                // derivation is checkable at all.
                .general(.startAtLogin),
                .general(.advancedRestartOnCrash),
                .profiles(.profileBindings),
                // Found BY the derivation: the copy action sits
                // on the App Bar card while the switch that
                // kills it is on the Space Bar card, so nothing
                // beside it says why it is dead.
                .spaceBar(.copyAppearance),
            ]
        )
    }

    /// The other two channels, pinned by one member each — a
    /// derivation that collapsed to "everything is inline" would
    /// satisfy the test above only by also emptying these.
    @Test("adjacency and remoteness are still distinguished")
    func theOtherChannelsHoldMembers() {
        // Both inside the App Bar's Style disclosure: the reader
        // opens one thing and sees the cause beside the effect.
        #expect(
            channel(.appBar(.appBarBackgroundFit)) == .adjacent
        )
        // Advanced Colours: its bar-colour rows are gated by
        // switches that live on the Bars destination, which is
        // the case `AdvancedColorsHelp`'s anchors answer.
        #expect(
            channel(.appBar(.appBarActiveItemColor)) == .remote
        )
        // A row with no gate has no channel at all.
        #expect(channel(.appBar(.appBarThickness)) == nil)
    }

    /// `.remote` means "the `?` anchor on the other page names
    /// where to go", which is a claim about a surface — so it is
    /// CHECKED against the file that draws the anchor, not
    /// assumed. Anything else lets the channel assert an
    /// affordance nobody built.
    ///
    /// The per-space override editor is the case in hand: its
    /// gating control is declared in Layout Defaults, so the
    /// derivation answers `.remote`, and the editor draws no
    /// anchor — the reason reaches `.help()` only. Recorded here
    /// rather than left as prose so the gap cannot be mistaken
    /// for coverage, and so the day the anchor lands this fails
    /// and asks for the entry to move out.
    @Test("the per-space overrides' remote gap is recorded")
    func perSpaceOverridesAwaitTheirAnchor() throws {
        for key: SettingKey in [
            .layout(.gridOverrideColumns),
            .layout(.gridOverrideRows),
            .layout(.trackOverrideLimit),
        ] {
            #expect(
                channel(key) == .remote,
                Comment(
                    rawValue:
                        "\(key.id) changed channel — if its "
                        + "gating control now has a row on the "
                        + "per-space surface, this class is no "
                        + "longer waiting on a `?` anchor"
                )
            )
        }
        // The gap itself: the rows' own file draws no `?`, so
        // `.remote` currently points at nothing for them. When
        // this stops being true, this suite is where the claim
        // gets re-stated.
        let path = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "SpaceOverrides/SpaceOverrideRows"
                    + "+ModeRows.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: path, encoding: .utf8)
        )
        #expect(
            !source.contains("HelpButton"),
            Comment(
                rawValue:
                    "the per-space rows gained an anchor — "
                    + "#815's remote class is closed, so move "
                    + "these keys out of this test"
            )
        )
    }

    /// The one row the derivation found is actually drawn, and
    /// drawn OUTSIDE the dim — a sentence inside the greyed
    /// subtree is the dead end the rule exists to remove.
    @Test("the found row draws its reason outside the dim")
    func theFoundRowDrawsItsReason() throws {
        let path = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Bars/"
                    + "AppBarCard.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: path, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        // The GreyOut closes BEFORE the sentence opens: the
        // dimmed subtree is the inner stack, and the `if` is its
        // sibling.
        let dim = try #require(
            source.range(of: "GreyOut(active:sourceBarOff")
        )
        let sentence = try #require(
            source.range(
                of: "ifsourceBarOff,owesInlineGateReason{"
                    + "Text(BarsGateHelp.sentence("
            )
        )
        #expect(
            dim.upperBound < sentence.lowerBound,
            "the reason must be a sibling of the dimmed stack"
        )
        // And it is DRAWN off the derivation rather than off a
        // hand-rolled copy of it: a comment claiming the census
        // decides this, over an `if` that re-derives it, is the
        // dead-resolver shape (`gui.md`), and it would leave
        // this type answering for nobody.
        #expect(
            source.contains(
                "GateReasonPlacement.owesInlineReason("
                    + ".spaceBar(.copyAppearance))"
            )
        )
    }

    /// A surfacing condition dims nothing, so it carries no
    /// channel at all — the distinction that keeps
    /// `causeIsOnSurface` from answering two questions with one
    /// name.
    @Test("a presence condition has no reason to place")
    func surfacingConditionsCarryNoChannel() {
        #expect(SettingRuntimeGate.layersExist.greys == false)
        #expect(SettingRuntimeGate.reduceMotion.greys)
        // The Layers card surfaces on `layersExist`; nothing
        // there is dimmed, so nothing owes a sentence.
        #expect(channel(.shortcuts(.layers)) == nil)
    }
}
