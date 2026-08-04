import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The two clamps on the Monitors picture (#678 Phase 3, turn
/// 13b), split from `MonitorArrangementTests` on the file
/// ceiling.
///
/// A card is a DROP TARGET, which is what makes a clamp
/// necessary at all: a truthful scale drawing has no minimum
/// size, and a control does. So the scale has a floor, the drawn
/// size ratio has a cap, and both are asserted here as
/// arithmetic over the rectangles they produce.
@Suite("Monitor arrangement clamps")
struct MonitorClampTests {
    /// AppKit's global space: y grows UP, the main display's
    /// bottom-left is the origin.
    private func display(
        _ id: UInt32,
        _ name: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: y, width: width, height: height)
        )
    }

    private let canvas = CGSize(width: 700, height: 240)

    private func layout(
        _ displays: [Display],
        main: DisplayID? = nil,
        canvas: CGSize? = nil
    ) -> MonitorArrangement.Layout {
        MonitorArrangement.layout(
            displays: displays,
            mainID: main ?? displays.first?.id,
            canvas: canvas ?? self.canvas
        )
    }

    private func rect(
        _ result: MonitorArrangement.Layout,
        _ id: UInt32
    ) throws -> CGRect {
        try #require(
            result.displays.first { $0.id == DisplayID(id) }?.rect
        )
    }

    // MARK: - The ratio cap

    /// Below the cap nothing is touched — the boundary matters,
    /// because a cap that engaged at every ratio would quietly
    /// make the whole picture equal-sized cards again.
    @Test("at the ratio the cap stays away")
    func capIsInactiveAtTheThreshold() throws {
        let ratio = MonitorArrangement.maxDrawnRatio
        let displays = [
            display(1, "Small", x: 0, y: 0, width: 1000, height: 800),
            display(
                2,
                "Wide",
                x: 1000,
                y: 0,
                width: 1000 * ratio,
                height: 800
            ),
        ]
        let result = layout(displays)
        #expect(!MonitorArrangement.isApproximate(displays))
        let small = try rect(result, 1)
        let wide = try rect(result, 2)
        #expect(abs(wide.width / small.width - ratio) < 0.001)
    }

    /// The note the page shows has a PERCEPTIBILITY threshold the
    /// cap itself does not. A MacBook beside a 4K is 3840/1512 ≈
    /// 2.54 — over the cap, so the 4K is drawn 1.6% small — and a
    /// "not to scale" caption pinned permanently to the commonest
    /// two-display desk in the world teaches people to ignore
    /// captions.
    @Test("a barely-capped pair says nothing")
    func imperceptibleClampIsSilent() throws {
        let displays = [
            display(
                1,
                "MacBook",
                x: 0,
                y: 0,
                width: 1512,
                height: 982
            ),
            display(
                2,
                "4K",
                x: 1512,
                y: 0,
                width: 3840,
                height: 2160
            ),
        ]
        // Capped: the 4K really is drawn under true scale —
        // 2.5 x 1512 / 3840, i.e. 1.6% short — which the drawn
        // ratio shows directly.
        let result = layout(displays)
        let laptop = try #require(
            result.displays.first { $0.id == DisplayID(1) }?.rect
        )
        let big = try #require(
            result.displays.first { $0.id == DisplayID(2) }?.rect
        )
        #expect(
            abs(
                big.width / laptop.width
                    - MonitorArrangement.maxDrawnRatio
            ) < 0.001
        )
        // …and silent, because 1.6% is not something to caption.
        #expect(!MonitorArrangement.isApproximate(displays))
    }

    /// Past it the LARGER display is drawn down to exactly the
    /// cap — never the smaller one up, which would move every
    /// other rectangle — so the smallest display stays big enough
    /// to drop a space onto.
    @Test("past the ratio the larger display is capped")
    func capEngagesPastTheThreshold() throws {
        let ratio = MonitorArrangement.maxDrawnRatio
        let displays = [
            display(1, "Laptop", x: 0, y: 0, width: 1000, height: 800),
            display(
                2,
                "Ultrawide",
                x: 1000,
                y: 0,
                width: 5000,
                height: 1400
            ),
        ]
        let result = layout(displays)
        #expect(MonitorArrangement.isApproximate(displays))
        let small = try rect(result, 1)
        let wide = try rect(result, 2)
        // The ultrawide's LONGEST side lands on the cap times the
        // smallest display's longest side.
        #expect(
            abs(wide.width / max(small.width, small.height) - ratio)
                < 0.001
        )
        // Aspect survives the cap: it shrinks, it does not
        // squash.
        #expect(
            abs(wide.width / wide.height - 5000.0 / 1400.0) < 0.001
        )
        // The small display is untouched — only the outlier is:
        // its drawn size is the plain uniform scale of its own
        // frame, which the gap arithmetic below would not see.
        #expect(abs(small.width / small.height - 1000.0 / 800.0) < 0.001)
    }

    /// The cap shrinks around each display's CENTRE, so a capped
    /// display stays where the arrangement puts it. Shrinking can
    /// only open a gap; it can never push one rectangle onto
    /// another, which is what a repositioning clamp would risk.
    @Test("capping never overlaps two displays")
    func capOnlyOpensGaps() throws {
        let result = layout([
            display(1, "Laptop", x: 0, y: 0, width: 1000, height: 800),
            display(
                2,
                "Ultrawide",
                x: 1000,
                y: 0,
                width: 5000,
                height: 1400
            ),
        ])
        let small = try rect(result, 1)
        let wide = try rect(result, 2)
        #expect(!small.intersects(wide))
        #expect(wide.minX > small.maxX)
    }

    // MARK: - The floor

    /// Every card is a drop target, so the scale has a floor:
    /// past it the picture grows beyond the canvas and scrolls
    /// rather than shrinking a card below usable.
    @Test("the smallest card never goes under the minimum")
    func floorKeepsTheSmallestUsable() throws {
        // Four wide displays into a narrow pane: fitted, each
        // would be a sliver no chip could be dropped onto.
        let displays = (0..<4).map { index in
            display(
                UInt32(index + 1),
                "Screen \(index)",
                x: CGFloat(index) * 2560,
                y: 0,
                width: 2560,
                height: 1440
            )
        }
        let narrow = CGSize(width: 300, height: 240)
        let result = layout(displays, canvas: narrow)
        let minimum = MonitorArrangement.minimumCard
        for drawn in result.displays {
            #expect(drawn.rect.width >= minimum.width - 0.001)
            #expect(drawn.rect.height >= minimum.height - 0.001)
        }
        // …and the picture grew rather than silently clipping:
        // the content is wider than the canvas, which is what
        // makes it scroll.
        #expect(result.contentSize.width > narrow.width)
    }

    /// The floor is the ONE-chip floor, derived from the chip it
    /// exists to fit rather than chosen — so a card at the floor
    /// can always show a chip, and a five-display desk is not
    /// forced into a scrolling picture by a comfort margin.
    /// Bounded from BOTH sides. The first cut asserted only
    /// `capacity == 1`, which caps the floor from above and
    /// leaves it free to fall to the padding — a card one point
    /// too narrow for the chip it exists to fit passed
    /// (guard-prover, 2026-08-04). The lower bound is the claim
    /// that matters: at the floor, a chip actually fits.
    @Test("the floor is exactly one chip's worth")
    func floorFitsOneChip() {
        let minimum = MonitorArrangement.minimumCard
        let area = MonitorCardChips.chipArea(in: minimum)
        // Lower bound: one chip fits, in both axes.
        #expect(area.width >= MonitorCardChips.minChipWidth)
        #expect(area.height >= MonitorCardChips.chipHeight)
        // Upper bound: exactly one — the floor is the boundary,
        // not a comfortable margin past it.
        #expect(MonitorCardChips.capacity(in: minimum) == 1)
        #expect(
            area.width
                < MonitorCardChips.minChipWidth * 2
                + MonitorCardChips.spacing
        )
    }

    /// A canvas roomy enough for the floor leaves the FIT scale
    /// in charge — the floor raises the scale, it does not pin
    /// it.
    ///
    /// Asserted as the fit itself, not as "big enough": a picture
    /// that always floored satisfied both of the first cut's
    /// bounds, since a floored 2560×1440 is still wider than the
    /// minimum card and still inside the canvas (guard-prover,
    /// 2026-08-04). One display fills its canvas in the bound
    /// axis — here the height — and nothing but that equality
    /// distinguishes the two scales.
    @Test("a roomy canvas is fitted, not floored")
    func fitWinsWhenThereIsRoom() throws {
        let displays = [
            display(1, "Desk", x: 0, y: 0, width: 2560, height: 1440)
        ]
        let result = layout(displays)
        let card = try rect(result, 1)
        // 2560×1440 into 700×240 is height-bound, so a fitted
        // picture fills the canvas — MINUS the band reserved for
        // the tray, which is part of the content and so part of
        // what has to fit.
        let band =
            MonitorArrangement.trayHeight
            + MonitorArrangement.trayGap
        #expect(
            abs(card.height - (canvas.height - band)) < 0.001
        )
        #expect(
            abs(result.contentSize.height - canvas.height) < 0.001
        )
        #expect(result.contentSize.width <= canvas.width + 0.001)
        #expect(
            card.width > MonitorArrangement.minimumCard.width
        )
    }

    // MARK: - Degenerate input

    /// A smoke test, and stated as one rather than mistaken for
    /// coverage: the empty picture is defended twice — the
    /// `drawable.isEmpty` guard in `layout` and `fold`'s own
    /// `cards.isEmpty` — and with either removed `union([])` is
    /// `.zero` and no anchor is found, so the empty `Layout`
    /// comes back anyway. No single mutation reds it
    /// (guard-prover, 2026-08-04). It is here to catch a crash or
    /// a NaN, not to hold an invariant.
    @Test("no displays draws nothing")
    func emptyDrawsNothing() {
        let result = layout([])
        #expect(result.displays.isEmpty)
        #expect(result.tray == nil)
        #expect(result.contentSize == .zero)
    }

    /// A zero-sided display is dropped rather than drawn: it can
    /// be neither seen nor dropped onto, and it would take the
    /// ratio cap's divisor to zero — every other rectangle would
    /// vanish with it.
    @Test("a zero-sized display is dropped, not drawn")
    func zeroSizedIsDropped() throws {
        let result = layout([
            display(1, "Real", x: 0, y: 0, width: 1512, height: 982),
            display(2, "Phantom", x: 0, y: 0, width: 0, height: 0),
        ])
        #expect(result.displays.count == 1)
        #expect(result.displays.first?.id == DisplayID(1))
        #expect(try rect(result, 1).width > 0)
    }
}
