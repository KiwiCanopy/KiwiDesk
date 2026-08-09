import Foundation
import Testing

@testable import KiwiDesk

/// The Monitors views are wired to their seams (#678 Phase 3,
/// turn 13b).
///
/// General shipped a round-1 cut whose resolver was built only in
/// tests while the views re-derived each predicate inline; the
/// census gate and the screen could then drift with every gate
/// test still green. Profiles then shipped the same shape one
/// level over — a family seam with no call sites, so its guards
/// asserted over a structure the screen never touched.
///
/// SCOPE: by explicit path, one entry per GATE and per SEAM
/// rather than per file, because a file-level "touches the
/// resolver somewhere" check passes while one of several gates
/// goes hand-rolled.
@Suite("Monitors gate and seam wiring")
struct MonitorsGateWiringTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private func read(_ path: String) throws -> String {
        try String(
            contentsOf: settingsDir.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// Whitespace-free source, so a needle survives the formatter
    /// wrapping a call across lines.
    private func squashed(_ path: String) throws -> String {
        SourceScan.stripComments(try read(path))
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    @Test("each gate is wired to the resolver, not a copy")
    func rowsConsultTheResolver() throws {
        let consults: [String: [String]] = [
            // One consult, not three: the picture's rows carry no
            // gate of their own, because a second inverted copy
            // of the banner's condition is a thing that can drift
            // from it (architect review, 2026-08-04).
            "Sections/MonitorsSection.swift": [
                "inertReason(for:.monitors(.placementUnavailable))"
            ],
            "Sections/MonitorsSection+Details.swift": [
                "inertReason(for:.monitors(.orphanPinClear))"
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
        }
    }

    /// The bespoke containers derive their instances from
    /// `MonitorsFamilyRows`, not from re-derivations of their
    /// own — otherwise the census guards assert over lists the
    /// screen never sees.
    ///
    /// Stated limit: this pins that each view CALLS the seam, not
    /// that it renders what it gets back.
    @Test("the views consult the family seam")
    func viewsConsultTheFamilySeam() throws {
        let consults: [String: [String]] = [
            "Components/Monitors/DisplayCard.swift": [
                // The ASSIGNMENT site, not the call: the bare
                // call appears twice in this file, and the
                // tooltip's copy satisfied this needle while the
                // chips themselves were hand-rolled from
                // `model.config.spacePins` — green on the whole
                // suite (guard-prover, 2026-08-04).
                "letassignments=rows.chips(on:display.fingerprint)"
            ],
            "Components/Monitors/FollowsMainTray.swift": [
                "rows.trayChips",
                // The tray holds chips in a fixed band exactly as
                // a card does, so it takes the same overflow
                // arithmetic. It was the one unbounded chip
                // container left, clipping every space past its
                // first row along with that space's clear button
                // and menu (architect review, 2026-08-04).
                "MonitorCardChips.split(spaces,in:size,header:",
                "overflowChip(spaces,split.overflow)",
            ],
            "Sections/MonitorsSection+Details.swift": [
                "rows.orphans",
                "rows.orderedDisplays",
            ],
            "Sections/MonitorsSection.swift": [
                "model.monitorRows"
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

    /// Every conditional BRANCH this area draws is named here,
    /// not just every gate.
    ///
    /// This is the hole guard-prover opened on the first cut: the
    /// resolver was consulted, the seam was called and the census
    /// agreed — all of which the suites above check — while five
    /// separate `if`s inside `body` could each be deleted with
    /// the whole 2813-test suite green. A surfacing gate leaves
    /// no greyed control to assert on, so nothing observed
    /// whether the view acted on the answer it was given: the
    /// orphan card's condition, the two notes, the `+n` and the
    /// tray's own gate all rendered by nothing but hope.
    ///
    /// Stated limit: a needle proves the branch is WRITTEN, not
    /// that it draws what it should — that half needs the eye.
    @Test("every surfacing branch is drawn, not just resolved")
    func surfacingBranchesAreDrawn() throws {
        let draws: [String: [String]] = [
            "Sections/MonitorsSection.swift": [
                // The PICTURE, which is the branch the census no
                // longer names: dropping the gate from
                // `.spacePins` retired its needle too, and
                // deleting this `else` draws nothing whenever
                // monitors are attached — with every needle
                // inside `picture(rows:)` still matching, because
                // they are still in the file, and no compiler
                // warning, because it is a private func
                // (architect review round 2, 2026-08-04).
                "}else{picture(rows:rows)}",
                // The orphan card's own surfacing condition, fed
                // from the live orphans rather than a constant.
                "hasOrphanedPins:!rows.orphans.isEmpty",
                // The two notes that say what the picture cannot
                // draw. Each is the ONLY consumer of its
                // derivation, so deleting the `if` retires the
                // whole promise silently.
                "MonitorArrangement.isApproximate(rows.displays)",
                "rows.hasAmbiguousDisplays",
            ],
            "Components/Monitors/DisplayCard.swift": [
                // The `+n` itself, not merely the arithmetic
                // behind it: `cardCountsOverflow` stayed green
                // with the marker deleted and the chips clipped
                // again.
                //
                // Keyed on the CALL with its arguments. A bare
                // `overflowChip(` is a substring of the helper's
                // own `private func overflowChip(` declaration,
                // so it watched "the function still exists" while
                // the call site was replaced by an `EmptyView()`
                // — green on the whole suite (guard-prover round
                // 2, 2026-08-04). Same defect as the family-seam
                // needle two entries down, and the same fix.
                "split.overflow>0",
                "overflowChip(assignments,split.overflow)",
                // The main display's glow (#758). Decoration —
                // the badge is the answer — but a decoration
                // branch deletes as silently as any other.
                "isMain?SettingsTheme.accent",
            ],
            "Components/Monitors/SpaceAssignmentChip.swift": [
                // The clear-pin corner badge (#758): the overlay
                // that mounts it, keyed on the USE site, and the
                // glyph inside the branch — deleting either
                // strands every pinned chip with no route back
                // to automatic except the context menu.
                ".overlay(alignment:.topTrailing){clearBadge}",
                "Image(systemName:\"xmark.circle.fill\")",
            ],
            "Sections/MonitorsSection+Details.swift": [
                // The orphan row's spoken label: its value is a
                // bare fingerprint hash, which VoiceOver steps
                // through with no context unless the row says
                // what it is (docs review, 2026-08-04).
                //
                // Keyed on the KEY, not on `accessibilityLabel(`
                // — the fingerprint drawer two functions below
                // carries one of those already, so the bare
                // modifier name could never fail (code review
                // round 2, 2026-08-04).
                "\"monitors.orphan_pin.row_axlabel\""
            ],
        ]
        for (name, needles) in draws {
            let source = try squashed(name)
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) no longer draws `\(needle)` "
                            + "— the branch is gone and every "
                            + "resolver and seam guard stays "
                            + "green without it"
                    )
                )
            }
        }
    }

    /// The picture asks `MonitorArrangement` for its geometry and
    /// computes none of its own.
    ///
    /// This is the #702 rule one surface over: a drawing that
    /// re-derives what a shared function owns is right the day it
    /// is written and drifts the day the rule moves. Here the
    /// shared function is also the only thing the geometry guards
    /// can see — a card positioned by arithmetic inline in the
    /// view would pass every assertion in
    /// `MonitorArrangementTests` while drawing something else.
    @Test("the picture asks the arrangement for its geometry")
    func pictureAsksTheArrangement() throws {
        let name = "Components/Monitors/MonitorsPicture.swift"
        let source = try squashed(name)
        #expect(source.contains("MonitorArrangement.layout("))
        for forbidden in ["frame.minX", "frame.width", "NSScreen"] {
            #expect(
                !source.contains(forbidden),
                Comment(
                    rawValue:
                        "\(name) reads display geometry itself "
                        + "(`\(forbidden)`) instead of drawing "
                        + "the arrangement it was given"
                )
            )
        }
    }

    /// The picture's chrome reads its numbers from
    /// `SettingsTheme`, which is the one copy (#758) — a stand
    /// or stroke re-hardcoded beside the drawing is the drift
    /// the theme constants exist to end.
    ///
    /// The stroke needle is the WHOLE ternary: the rest-weight
    /// name is a substring of the selected-weight name, so a
    /// bare `monitorCardStroke` check would stay green with the
    /// rest weight hardcoded back to a literal.
    @Test("the chrome reads its themed metrics")
    func chromeReadsThemedMetrics() throws {
        let picture = try squashed(
            "Components/Monitors/MonitorsPicture.swift"
        )
        for needle in [
            "SettingsTheme.monitorStandScale",
            "SettingsTheme.monitorStandMin",
            "SettingsTheme.monitorStandMax",
        ] {
            #expect(
                picture.contains(needle),
                Comment(
                    rawValue:
                        "MonitorsPicture no longer reads "
                        + "`\(needle)` — the stand's size went "
                        + "inline"
                )
            )
        }
        let card = try squashed(
            "Components/Monitors/DisplayCard.swift"
        )
        #expect(
            card.contains(
                "SettingsTheme.monitorCardStrokeSelected"
                    + ":SettingsTheme.monitorCardStroke)"
            ),
            Comment(
                rawValue:
                    "DisplayCard's border no longer takes both "
                    + "weights from SettingsTheme"
            )
        )
    }

    /// The card's chip capacity comes from the shared arithmetic,
    /// so a card can never resolve "more chips than fit" by
    /// clipping them — which would take the clear button and the
    /// drag handle with them.
    @Test("the card counts its overflow rather than clipping")
    func cardCountsOverflow() throws {
        let name = "Components/Monitors/DisplayCard.swift"
        let source = try squashed(name)
        #expect(source.contains("MonitorCardChips.split("))
    }

    /// One sentence, one author: the card's tooltip and the line
    /// under the picture are the same claim about the same
    /// display, and two copies is how a tooltip comes to disagree
    /// with the caption beside it.
    ///
    /// The author's half reads STRIPPED source. Reading it raw
    /// let a deleted branch pass on the comment left behind
    /// (`// was: monitors.selection.showing`), so the guard could
    /// not tell a call site from a mention of one (guard-prover,
    /// 2026-08-04). The non-author halves stay raw on purpose:
    /// there a comment quoting the key reds, which is fail-closed
    /// and cheap to fix.
    @Test("the readout sentence is authored once")
    func readoutIsAuthoredOnce() throws {
        let author =
            "Components/Monitors/MonitorReadout.swift"
        let help = SourceScan.stripComments(try read(author))
        for key in [
            "monitors.selection.one",
            "monitors.selection.many",
            "monitors.selection.showing",
        ] {
            #expect(help.contains(key))
            for name in [
                "Sections/MonitorsSection.swift",
                "Components/Monitors/DisplayCard.swift",
            ] {
                #expect(
                    !(try read(name)).contains(key),
                    Comment(
                        rawValue:
                            "\(name) re-authors \(key) — it must "
                            + "come from MonitorReadout"
                    )
                )
            }
        }
    }
}
