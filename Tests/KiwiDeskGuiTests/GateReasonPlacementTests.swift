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
    ///
    /// Stated reach, since a green here is narrower than it
    /// looks: `channel` reads a row's OWN `gate:`, so a
    /// condition used only as a CONTAINER gate never reaches
    /// `causeIsOnSurface` at all — flipping `.reduceMotion`'s
    /// answer changes nothing here, proven by mutation
    /// (guard-prover, 2026-08-12). Promoting a container-only
    /// condition to a row gate therefore arrives carrying an
    /// answer nothing has ever checked; that promotion owes a
    /// case in this set.
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

    /// `SpacesGateHelp.remote` agrees with the census.
    ///
    /// The set is a second, hand-kept copy of an answer
    /// `GateReasonPlacement.channel` already derives — keyed on
    /// the REASON where the census is keyed on the `SettingKey`
    /// — so nothing stopped the two drifting: a gate retargeted
    /// to an on-page owner would leave the anchor drawing, and a
    /// new `.remote` row would get none (architect review,
    /// 2026-08-16). This binds them until the derivation
    /// replaces the copy.
    @Test("the remote reason set agrees with the census")
    func remoteMatchesTheCensus() {
        // Every key the census calls `.remote` on this surface
        // resolves to a reason the set contains…
        let remoteKeys: [SettingKey] = [
            .layout(.gridOverrideColumns),
            .layout(.gridOverrideRows),
            .layout(.trackOverrideLimit),
        ]
        for key in remoteKeys {
            #expect(channel(key) == .remote)
        }
        // …and the set names only reasons those keys produce, so
        // it cannot grow an entry the census does not back.
        #expect(
            SpacesGateHelp.remote == [.autoSizedGrid, .autoTracks]
        )
        // The co-located sibling stays OUT, by the census's own
        // answer rather than by assertion: its owner renders as
        // the row directly above it.
        #expect(
            channel(.layout(.gridOverrideFillEmptyCells))
                != .remote
        )
        #expect(
            !SpacesGateHelp.remote.contains(.rigidGrid)
        )
    }

    /// The per-space overrides' remote anchor, now that it
    /// exists (#841, closed 2026-08-16).
    ///
    /// This test used to RECORD the gap — the three rows were
    /// classified `.remote` and drew no anchor at all, so their
    /// reason reached `.help()` only and a keyboard or VoiceOver
    /// user got "dimmed" and nothing else. It was written to
    /// fail the day an anchor landed, which is what asked for
    /// this rewrite.
    ///
    /// It now asserts the anchor rather than its absence, and
    /// asserts the two halves the rule actually requires: the
    /// sentence NAMES A DESTINATION, and it is a live link
    /// rather than a `Text`, or the pointer is dead
    /// (`docs/ui-patterns.md`).
    @Test("the per-space remote gates carry a live anchor")
    func perSpaceOverridesCarryTheirAnchor() throws {
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
                        + "per-space surface, it no longer needs "
                        + "the remote anchor below"
                )
            )
        }
        let path = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "SpaceOverrides/SpaceOverrideRows"
                    + "+ModeRows.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: path, encoding: .utf8)
        )
        .filter { !$0.isWhitespace }
        // A LIVE pointer, not hover text.
        #expect(
            source.contains("CrossReferenceRow("),
            Comment(
                rawValue:
                    "the remote rows lost their anchor — a dim "
                    + "with only `.help()` is the dead end #841 "
                    + "closed"
            )
        )
        // Both gated classes reach it, not just whichever one
        // was fixed first.
        for key in [
            "gridOverrideColumns", "trackOverrideLimit",
        ] {
            #expect(
                source.contains(
                    "remoteGateReference(for:.layout(.\(key))"
                ),
                Comment(
                    rawValue: "\(key) draws no remote anchor"
                )
            )
        }
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
        // sibling. Both ranges are FIRST occurrences, so a
        // second dim block later in this file wrapping the
        // sentence would compare against the first and pass —
        // stated rather than chased, the file having one.
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
