import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Gaps & Borders' gate resolver (#678 Phase 3): the Focus-border
/// CONTAINER gate, the row gates (glow size, drag sub-rows), and
/// the gap masters, which carry NO gate and acknowledge instead
/// (#1383).
@Suite("Gaps & Borders gates")
struct GapsAndBordersGateTests {
    private func settings(
        border: Bool = true,
        glow: Bool = true,
        ghost: Bool = true,
        ghostBorder: Bool = true,
        dropZone: Bool = true,
        dropZoneBorder: Bool = true,
        outerEdgesDiffer: Bool = false,
        innerAxesDiffer: Bool = false
    ) -> TilingSettings {
        var s = TilingSettings()
        s.borderStyle.enabled = border
        s.borderStyle.glow = glow
        s.dragGhost.enabled = ghost
        s.dragGhost.border = ghostBorder
        s.dragDropZone.enabled = dropZone
        s.dragDropZone.border = dropZoneBorder
        s.gapsGlobal.outer = Gaps.Outer(
            top: 10,
            bottom: outerEdgesDiffer ? 4 : 10,
            left: 10,
            right: 10
        )
        s.gapsGlobal.inner = Gaps.Inner(
            horizontal: 10,
            vertical: innerAxesDiffer ? 4 : 10
        )
        return s
    }

    private func gates(
        _ overrides: (inout TilingSettings) -> Void = { _ in }
    ) -> GapsBordersGates {
        var s = settings()
        overrides(&s)
        return GapsBordersGates(settings: s)
    }

    /// The declared-vs-answered split, read off the census: a new
    /// gated ROW in this area that lands in neither set reds here
    /// rather than failing open at runtime.
    @Test("every gated row is resolved somewhere")
    func everyGatedRowIsResolved() {
        let gated = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .gapsAndBorders
                    && $0.placement.gate != nil
            }
        )
        #expect(
            gated
                == GapsBordersGates.resolved
                .union(GapsBordersGates.resolvedElsewhere)
        )
        #expect(
            GapsBordersGates.resolved.isDisjoint(
                with: GapsBordersGates.resolvedElsewhere
            )
        )
    }

    /// The one CONTAINER gate this area carries — Layout Defaults
    /// has none, so this net does not exist there. `.focusBorder`
    /// is the only container with a gate, and the resolver answers
    /// it both ways.
    @Test("the focus-border block gate is resolved")
    func containerGateIsResolved() {
        let gatedContainers = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .gapsAndBorders }
                .compactMap { $0.placement.container }
                .filter { $0.gate != nil }
        )
        #expect(gatedContainers == [.focusBorder])
        #expect(
            gates { $0.borderStyle.enabled = false }
                .containerReason(for: .focusBorder) == .borderOff
        )
        #expect(
            gates { $0.borderStyle.enabled = true }
                .containerReason(for: .focusBorder) == nil
        )
        // No other container greys: a stray reason would dim a
        // whole card with nothing declaring it.
        for container in GapsBordersRowOrder.byContainer.keys
        where container != .focusBorder {
            #expect(
                gates().containerReason(for: container) == nil
            )
        }
    }

    /// An ungated row is never inert — the resolver's first guard,
    /// and what keeps its `default:` arm unreachable rather than
    /// merely believed to be. Runs with everything OFF, the state
    /// most likely to trip a stray predicate.
    @Test("ungated rows stay live")
    func ungatedRowsStayLive() {
        let g = GapsBordersGates(
            settings: settings(
                border: false,
                glow: false,
                ghost: false,
                ghostBorder: false,
                dropZone: false,
                dropZoneBorder: false
            )
        )
        for key in SettingKey.allCases
        where key.placement.area == .gapsAndBorders
            && key.placement.gate == nil
        {
            #expect(g.inertReason(for: key) == nil)
        }
    }

    /// The slider AND the auto toggle above it: neither has an
    /// effect while the glow is off, so both take the one reason
    /// (#1377 found the toggle live while the slider greyed).
    @Test(
        "glow size and its auto toggle grey with the glow effect off",
        arguments: [
            SettingKey.borders(.borderGlowSize),
            .borders(.borderGlowSizeAuto),
        ]
    )
    func glowSizeNeedsGlow(key: SettingKey) {
        // Border on, glow off → the row is inert.
        #expect(
            gates { $0.borderStyle.glow = false }
                .inertReason(for: key) == .glowOff
        )
        // Glow on → live (the auto sentinel greys the slider
        // separately).
        #expect(
            gates { $0.borderStyle.glow = true }
                .inertReason(for: key) == nil
        )
        // Border off → the block owns the grey; the row reason
        // stands down so its hover cannot shadow the block's.
        #expect(
            gates {
                $0.borderStyle.enabled = false
                $0.borderStyle.glow = false
            }
            .inertReason(for: key) == nil
        )
    }

    /// A column greys wholesale off its own Enabled toggle and
    /// off nothing else. Its Border toggle gates no row in this
    /// area since #754 took the width row out, so Border being
    /// off must leave every row in the column live — a resolver
    /// still reading it would grey Fill for a reason Fill does
    /// not have.
    @Test("the ghost column gates on enabled alone")
    func ghostColumnLayers() {
        let off = gates { $0.dragGhost.enabled = false }
        #expect(
            off.inertReason(for: .borders(.dragGhostBorder))
                == .visualOff
        )
        #expect(
            off.inertReason(for: .borders(.dragGhostFill))
                == .visualOff
        )
        let noBorder = gates { $0.dragGhost.border = false }
        #expect(
            noBorder.inertReason(
                for: .borders(.dragGhostBorder)
            ) == nil
        )
        #expect(
            noBorder.inertReason(
                for: .borders(.dragGhostFill)
            ) == nil
        )
        #expect(
            gates().inertReason(for: .borders(.dragGhostBorder))
                == nil
        )
    }

    @Test("the drop-zone column gates on enabled alone")
    func dropZoneColumnLayers() {
        let off = gates { $0.dragDropZone.enabled = false }
        #expect(
            off.inertReason(for: .borders(.dragDropZoneBorder))
                == .visualOff
        )
        #expect(
            off.inertReason(for: .borders(.dragDropZoneFill))
                == .visualOff
        )
        let noBorder = gates { $0.dragDropZone.border = false }
        #expect(
            noBorder.inertReason(
                for: .borders(.dragDropZoneBorder)
            ) == nil
        )
        #expect(
            noBorder.inertReason(
                for: .borders(.dragDropZoneFill)
            ) == nil
        )
    }

    /// A gap master is never gated: it stays live while its
    /// edges differ and ACKNOWLEDGES through `followersDiffer`
    /// (#1383 reversed the grey — dimmed means no input on every
    /// channel, and the drag is the one gesture that converges).
    @Test("a gap master acknowledges, never greys, while its edges differ")
    func gapMastersAcknowledgeOnDiffer() {
        let outer = GapsBordersGates(
            settings: settings(outerEdgesDiffer: true)
        )
        #expect(outer.followersDiffer(for: .gaps(.outer)))
        #expect(!gates().followersDiffer(for: .gaps(.outer)))
        let inner = GapsBordersGates(
            settings: settings(innerAxesDiffer: true)
        )
        #expect(inner.followersDiffer(for: .gaps(.inner)))
        #expect(!gates().followersDiffer(for: .gaps(.inner)))
        // Ungated in the census, so the resolver's first guard
        // answers nil whatever the edges say.
        for key in [SettingKey.gaps(.outer), .gaps(.inner)] {
            #expect(key.placement.gate == nil)
            #expect(outer.inertReason(for: key) == nil)
            #expect(inner.inertReason(for: key) == nil)
        }
    }

    /// Each follower ALONE diverges its master — an arm that
    /// compared top against bottom only would pass a fixture
    /// that moves every edge at once (guard-prover, #1383).
    @Test(
        "each gap edge or axis alone diverges its master",
        arguments: [
            "outer.top", "outer.bottom", "outer.left", "outer.right",
            "inner.horizontal", "inner.vertical",
        ]
    )
    func eachFollowerDivergesAlone(follower: String) {
        var s = settings()
        switch follower {
        case "outer.top": s.gapsGlobal.outer.top += 3
        case "outer.bottom": s.gapsGlobal.outer.bottom += 3
        case "outer.left": s.gapsGlobal.outer.left += 3
        case "outer.right": s.gapsGlobal.outer.right += 3
        case "inner.horizontal": s.gapsGlobal.inner.horizontal += 3
        default: s.gapsGlobal.inner.vertical += 3
        }
        let gates = GapsBordersGates(settings: s)
        let outer = follower.hasPrefix("outer")
        #expect(gates.followersDiffer(for: .gaps(.outer)) == outer)
        #expect(gates.followersDiffer(for: .gaps(.inner)) == !outer)
    }

    /// Every reason renders a distinct, non-empty sentence: a
    /// collapsed pair would send the reader to the wrong fix.
    @MainActor
    @Test("each inert reason renders its own sentence")
    func eachReasonHasItsOwnSentence() {
        let all: [GapsBordersGates.InertReason] = [
            .borderOff, .glowOff, .visualOff,
        ]
        let sentences = all.map(GapsBordersGateHelp.sentence)
        for sentence in sentences {
            #expect(!sentence.isEmpty)
        }
        #expect(Set(sentences).count == all.count)
    }

    /// The Fit rows on the Gaps card read the border they size
    /// for (#1360): inert with its own reason while it is off —
    /// their own, since the Focus Border block's sentence names
    /// that card's rows — live with it on.
    @Test(
        "the Fit rows grey with the focus border off",
        arguments: [
            SettingKey.borders(.borderFitGaps),
            .borders(.borderFitGapsExtraSpacing),
        ]
    )
    func fitRowsNeedTheBorder(key: SettingKey) {
        #expect(
            gates { $0.borderStyle.enabled = false }
                .inertReason(for: key) == .fitBorderOff
        )
        #expect(
            gates { $0.borderStyle.enabled = true }
                .inertReason(for: key) == nil
        )
    }
}
