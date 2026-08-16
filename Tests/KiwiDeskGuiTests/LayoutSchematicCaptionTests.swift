import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a preview's words are allowed to say (#753, #708).
///
/// Split from `LayoutSchematicScrollingTests` before that file
/// reached the ceiling, and they fail apart anyway: that suite
/// holds the drawing, this one holds the sentence beside it.
///
/// **Scrolling-only was the hole.** The rule this suite enforces —
/// a caption may not point at a mark the frame does not draw — is
/// general, and while the scan reached one schematic, Track shipped
/// a caption naming a far-edge overflow track that the strip draws
/// only when something overflows. At the shipped defaults
/// (`auto_tracks` on, five windows) nothing does, so the preview
/// asserted a track that was not there and VoiceOver asserted it
/// again (#708). A schematic whose caption carries a conditional
/// clause joins this suite in the same change that gives it one.
///
/// **These assertions read no English and cannot say which locale
/// they DO read.** `L()` resolves through the shipped catalogs and
/// several GUI suites call `LocalizationManager.shared.select(…)`
/// concurrently, so what these strings are in is whatever a
/// concurrent suite last set — the reason
/// `CrossReferenceRowSlotTests` gives for not pinning one here
/// either. Coverage survives that: every claim below is a
/// comparison between two rendered strings, or a search for a
/// term rendered from the same catalog.
///
/// `@MainActor` because the prose producers are members of a
/// `View`: off the main actor the first read traps in the
/// concurrency runtime rather than failing an expectation.
@Suite("Layout preview captions")
@MainActor
struct LayoutSchematicCaptionTests {
    /// Track's conditional clause, both directions. The words and
    /// the strip read ONE answer (`drawsOverflowTrack`), so this
    /// walks the whole slider band under both rules and both
    /// `auto_tracks` arms and requires the clause exactly where a
    /// track is drawn to carry it.
    ///
    /// The needle is the overflow clause's own rendered words,
    /// taken from the drawing arm's key — so it holds in whatever
    /// locale the run happens to be in, and a translation that
    /// smuggles the clause into the plain arm reds, which is the
    /// point rather than a side effect.
    @Test("Track claims the overflow track only when it draws one")
    func trackOverflowClauseMatchesTheDrawing() {
        for rule in [
            TrackParams.NewWindowTrack.ownTrack, .focusedTrack,
        ] {
            for auto in [true, false] {
                for count in LayoutSchematic.windowCountRange {
                    let s = trackPreview(
                        rule: rule,
                        auto: auto,
                        windows: count
                    )
                    let drawn = s.drawsOverflowTrack
                    let claims = s.caption != plainCaption(for: rule)
                    #expect(
                        claims == drawn,
                        Comment(
                            rawValue:
                                "\(rule)/auto=\(auto)/\(count): "
                                + "caption claims the overflow "
                                + "track \(claims), frame draws "
                                + "it \(drawn)"
                        )
                    )
                    // The spoken label may no more assert an
                    // undrawn track than the written one may.
                    #expect(
                        (s.axLabel != plainAxLabel()) == drawn
                    )
                }
            }
        }
    }

    /// The defaults specifically, because that is the shape a user
    /// meets on first opening the area — and the one the shipped
    /// caption was wrong about.
    @Test("Track's default frame draws no overflow track")
    func trackDefaultsDrawNoOverflow() {
        let s = trackPreview(rule: .focusedTrack, auto: true)
        #expect(!s.drawsOverflowTrack)
        #expect(s.caption == plainCaption(for: .focusedTrack))
        #expect(s.axLabel == plainAxLabel())
    }

    private func plainCaption(
        for rule: TrackParams.NewWindowTrack
    ) -> String {
        switch rule {
        case .ownTrack:
            return L(
                "layout.schematic.track.caption_own_plain",
                "New windows open their own track."
            )
        case .focusedTrack:
            return L(
                "layout.schematic.track.caption_focused_plain",
                "New windows join the focused track until it is "
                    + "full, then open one beside it."
            )
        }
    }

    private func plainAxLabel() -> String {
        L(
            "layout.schematic.track.ax_plain",
            "Track preview: tracks along one axis; the plus "
                + "is the next window."
        )
    }

    private func trackPreview(
        rule: TrackParams.NewWindowTrack,
        auto: Bool,
        windows: Int = LayoutSchematic.defaultWindowCount
    ) -> TrackSchematic {
        TrackSchematic(
            axis: .vertical,
            overflowStyle: .cascadeAll,
            newWindow: rule,
            placement: .last,
            limit: 3,
            autoTracks: auto,
            windows: windows,
            scale: .panel
        )
    }

    /// The words switch on the anchor, because the words are the
    /// only thing `follow` changes: its frame is `center`'s to the
    /// pixel (`LayoutSchematicScrollingTests`), so a caption
    /// shared with `center` makes selecting Follow a no-op on
    /// screen — and a shared caption stating Follow's pan has
    /// VoiceOver assert it over a tile drawn with Center
    /// selected.
    @Test("Follow says something Center does not")
    func theAnchorReachesTheWords() {
        let follow = scrolling(anchor: .follow)
        let centre = scrolling(anchor: .center)
        #expect(follow.caption != centre.caption)
        #expect(follow.axLabel != centre.axLabel)
        // And no other anchor carries a sentence about this one:
        // Follow's own name appears in Follow's words and nowhere
        // else. Read through the picker's own key, so this holds
        // in whatever locale the run is in — and so a translation
        // that reuses the term for the anchored caption reds,
        // which is the point rather than a side effect.
        let name = L("scroll_grid.anchor.follow", "Follow")
        #expect(follow.caption.contains(name))
        // Off `allCases`, never a literal three. A fifth anchor is
        // already swept for placement and for resting inside the
        // frame, so a hand-listed loop here would leave it — and
        // only it — unchecked for the term leak this lane fixed.
        for anchor in ScrollingParams.Anchor.allCases
        where anchor != .follow {
            let other = scrolling(anchor: anchor)
            #expect(!other.caption.contains(name))
            #expect(!other.axLabel.contains(name))
        }
    }

    /// The caption promises a `+` only where one is drawn.
    ///
    /// The row runs several canvases wide at most counts, so the
    /// incoming slot is often clipped away entirely — at the
    /// default five windows with New window ▸ Last it already is.
    /// The clause is a condition on the row and the scale rather
    /// than on the pixels, since the caption cannot read the
    /// canvas, so what is owed is the IMPLICATION: wherever it is
    /// claimed, the drawing's own `onCanvas` agrees, at every
    /// width a pane can be. Both directions of the pair are
    /// counted, so a clause that never fires cannot pass for a
    /// correct one.
    ///
    /// **Swept over the scale too, not only `.panel`.** The
    /// sufficiency argument for a slot adjacent to the focus runs
    /// on the margin the monitor leaves beside itself, and a
    /// thumbnail's monitor IS its canvas — so `end` with New
    /// window ▸ After focused puts the neighbour 3 pt past the
    /// border there. A scale-blind `drawsInsertionMark` claims
    /// that `+`, and only this axis sees it: `.tile` suppresses
    /// the caption today, so nothing else in the tree would go
    /// red until some thumbnail gained one.
    @Test("the + clause is claimed only where the + is drawn")
    func theInsertionClauseMatchesTheDrawing() {
        var claimed = 0
        var withheld = 0
        for scale in SchematicScale.allCases {
            for anchor in ScrollingParams.Anchor.allCases {
                for placement in placements {
                    for size in slotSizes {
                        for count in counts {
                            let schematic = scrolling(
                                anchor: anchor,
                                placement: placement,
                                slotSize: size,
                                windows: count,
                                scale: scale
                            )
                            guard
                                schematic.drawsInsertionMark
                            else {
                                withheld += 1
                                continue
                            }
                            claimed += 1
                            expectDrawn(
                                schematic,
                                "\(scale)/\(anchor)/\(placement) "
                                    + "at \(count)"
                            )
                        }
                    }
                }
            }
        }
        #expect(claimed > 0)
        #expect(withheld > 0)
    }

    /// The claim is width-free, so it owes every along-axis length
    /// a pane can take rather than one convenient canvas.
    private func expectDrawn(
        _ schematic: ScrollingSchematic,
        _ what: String
    ) {
        for along in widths {
            let m = schematic.metrics(along: along)
            #expect(
                schematic.onCanvas(m.newIdx, m, along: along),
                Comment(
                    rawValue:
                        "\(what), \(along) pt: + off the canvas"
                )
            )
        }
    }

    /// And the clause is what the claim renders — the sentence is
    /// in the caption exactly when the mark is on the frame, with
    /// no dangling space where it went.
    @Test("the caption carries the clause it claims")
    func theClauseIsRendered() {
        let beside = scrolling(placement: .afterFocused)
        let far = scrolling(
            placement: .last,
            windows: LayoutSchematic.windowCountRange.upperBound
        )
        #expect(beside.drawsInsertionMark)
        #expect(!far.drawsInsertionMark)
        #expect(!beside.insertionClause.isEmpty)
        #expect(far.insertionClause.isEmpty)
        #expect(beside.caption.contains(beside.insertionClause))
        #expect(far.caption.count < beside.caption.count)
        #expect(!far.caption.hasSuffix(" "))
    }

    // MARK: - Fixtures

    private let placements: [SpawnPlacement] = [
        .first, .last, .beforeFocused, .afterFocused,
    ]

    /// Every count the preview's own slider can reach.
    private var counts: ClosedRange<Int> {
        LayoutSchematic.windowCountRange
    }

    /// The slot sizes the three `ScrollSize` arms can produce,
    /// including both ends of the points ramp: the 14 pt floor and
    /// the widest slot are where a width-free claim would break if
    /// it were going to.
    private let slotSizes: [ScrollSize] = [
        .auto, .fraction(0.12), .fraction(0.92), .points(100),
        .points(1200),
    ]

    /// The along-axis lengths a panel can take, from a pane
    /// squeezed beside the override rows at the 720 pt minimum
    /// window to a full-screen one.
    private let widths: [CGFloat] = [60, 120, 228, 400, 900, 1600]

    /// `.panel` by default: the caption is the subject and a
    /// thumbnail suppresses it, so every test whose subject is the
    /// rendered words reads the scale that renders them. The one
    /// that asks what the clause is *allowed* to claim overrides
    /// it — see `theInsertionClauseMatchesTheDrawing`.
    private func scrolling(
        anchor: ScrollingParams.Anchor = .center,
        placement: SpawnPlacement = .last,
        slotSize: ScrollSize = .auto,
        windows: Int = LayoutSchematic.defaultWindowCount,
        scale: SchematicScale = .panel
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: anchor,
            slotSize: slotSize,
            placement: placement,
            windows: windows,
            scale: scale
        )
    }
}
