import CoreGraphics
import Testing

@testable import KiwiDesk

/// A display card's chip capacity (#678 Phase 3, turn 13b).
///
/// The card's SIZE comes from the monitor and its chip COUNT from
/// the config, so the two can disagree — and the first cut of the
/// picture resolved that by clipping, which deletes a chip along
/// with its clear button and its drag handle, the only two ways
/// back out of a pin. These assertions are the arithmetic that
/// replaced the clip: a card that cannot show them all says how
/// many it is holding back.
@Suite("Display card chip capacity")
struct MonitorCardChipsTests {
    private let floor = MonitorArrangement.minimumCard

    @Test("the smallest card still holds one chip")
    func floorHoldsOne() {
        #expect(MonitorCardChips.capacity(in: floor) == 1)
    }

    /// The chip stacks hold exactly TWO children, so the one gap
    /// the arithmetic subtracts is the whole of it.
    ///
    /// Read off the SOURCE, because that is the half the
    /// arithmetic cannot see. A first cut asserted
    /// `chipArea(in:).height == size - (padding*2 + header +
    /// stackSpacing)` — the same three terms `chipArea` itself
    /// subtracts, in the same order — so both sides came out of
    /// one expression and the test could not see that
    /// `DisplayCard`'s stack had a third child and therefore a
    /// second gap (code review, 2026-08-04). What matters is not
    /// the formula but the layout it claims to model.
    @Test("the chip stacks hold two children and one gap")
    func stacksMatchTheArithmetic() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Monitors"
            )
        for name in ["DisplayCard.swift", "FollowsMainTray.swift"] {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: dir.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
            let squashed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            // The stack is laid out with the very constant the
            // capacity subtracts, never a literal beside it.
            #expect(
                squashed.contains(
                    "spacing:MonitorCardChips.stackSpacing"
                ),
                Comment(
                    rawValue:
                        "\(name)'s chip stack no longer uses the "
                        + "spacing the capacity arithmetic "
                        + "subtracts"
                )
            )
            // …and it holds `header` then `chips` and nothing
            // else: a third child is a second gap the arithmetic
            // does not know about.
            #expect(
                squashed.contains(
                    "MonitorCardChips.stackSpacing){headerchips}"
                ),
                Comment(
                    rawValue:
                        "\(name)'s chip stack grew a third child "
                        + "— that is a second gap, and the chip "
                        + "area still subtracts one"
                )
            )
        }
    }

    /// The `+n` is a COLUMN beside the wrapped chips, so it
    /// narrows every row — reserving it once per card let three
    /// chips flow into three rows inside a band sized for two,
    /// and the last row clipped (code review, 2026-08-04).
    @Test("the marker's column is reserved, not its slot")
    func markerReservesItsColumn() {
        let card = CGSize(
            width: floor.width + MonitorCardChips.minChipWidth
                + MonitorCardChips.spacing,
            height: floor.height + MonitorCardChips.chipHeight
                + MonitorCardChips.spacing
        )
        let plain = MonitorCardChips.capacity(in: card)
        let reserved = MonitorCardChips.capacity(
            in: card,
            reservingMarker: true
        )
        #expect(reserved < plain)
        // Everything shown fits BESIDE the marker: the shown
        // chips need no more width than the row has left once the
        // `+n` column is taken.
        let split = MonitorCardChips.split(
            Array(0..<12),
            in: card
        )
        let area = MonitorCardChips.chipArea(in: card)
        // The row count comes from the production helper, not a
        // second copy of its formula — the first cut's copy had
        // already dropped the clamp (code review, 2026-08-04).
        let rows = MonitorCardChips.rows(in: card)
        // The WORST row, not the average: an uneven fill puts
        // more chips in the first row than the mean, and the mean
        // would let the guard weaken silently instead of failing.
        let perRow = (Double(split.shown.count) / Double(rows))
            .rounded(.up)
        let needed =
            perRow
            * Double(
                MonitorCardChips.minChipWidth
                    + MonitorCardChips.spacing
            )
        #expect(
            needed
                <= area.width - MonitorCardChips.markerWidth
                + 0.001
        )
    }

    /// The overflow marker never names ONE hidden chip, because
    /// it takes a slot of its own — which is why
    /// `monitor_card.more_spaces.axlabel` has no singular. Pinned
    /// as the general property rather than at the two counts the
    /// other tests happen to use (localization audit,
    /// 2026-08-04).
    @Test("an overflow is never exactly one")
    func overflowIsNeverOne() {
        for count in 0..<12 {
            for side in [floor.width, 120.0, 260.0] {
                let card = CGSize(width: side, height: floor.height)
                let split = MonitorCardChips.split(
                    Array(0..<count),
                    in: card
                )
                #expect(
                    split.overflow == 0 || split.overflow >= 2,
                    Comment(
                        rawValue:
                            "\(count) chips in \(card) hid "
                            + "exactly one — the label has no "
                            + "singular"
                    )
                )
            }
        }
    }

    /// Capacity is derived, not constant: a card twice as tall
    /// holds more rows, and one twice as wide holds more per row.
    @Test("capacity grows with the card")
    func capacityFollowsSize() {
        let taller = CGSize(
            width: floor.width,
            height: floor.height + MonitorCardChips.chipHeight
                + MonitorCardChips.spacing
        )
        #expect(MonitorCardChips.capacity(in: taller) == 2)
        let wider = CGSize(
            width: floor.width + MonitorCardChips.minChipWidth
                + MonitorCardChips.spacing,
            height: floor.height
        )
        #expect(MonitorCardChips.capacity(in: wider) == 2)
    }

    /// A card with room for everything shows everything and marks
    /// nothing — the `+n` must not appear on a card that fits.
    @Test("no overflow when they all fit")
    func nothingHiddenWhenTheyFit() {
        let big = CGSize(width: 400, height: 300)
        let chips = Array(0..<4)
        let split = MonitorCardChips.split(chips, in: big)
        #expect(split.overflow == 0)
        #expect(split.shown == chips)
    }

    /// The `+n` takes a slot of its own, so the count it names is
    /// the count actually hidden — an overflow marker that pushed
    /// out a chip it then failed to mention is the clip again,
    /// one chip smaller.
    @Test("the overflow marker counts itself out")
    func overflowAccountsForItsOwnSlot() {
        let chips = Array(0..<5)
        let split = MonitorCardChips.split(chips, in: floor)
        // Capacity 1: the marker takes it, so nothing is shown
        // and all five are behind it.
        #expect(split.shown.isEmpty)
        #expect(split.overflow == 5)
        // Every chip is reachable: shown plus hidden is the whole
        // list, which is the promise the clip broke.
        #expect(split.shown.count + split.overflow == chips.count)
    }

    /// A card two chips wide and two rows tall holds four — but
    /// once the `+n` claims a column, each row has room for one,
    /// so five chips show two and hide three. The marker costs a
    /// COLUMN, not a chip.
    @Test("the marker's column costs a chip in every row")
    func oneOverHidesTwo() {
        let card = CGSize(
            width: floor.width + MonitorCardChips.minChipWidth
                + MonitorCardChips.spacing,
            height: floor.height + MonitorCardChips.chipHeight
                + MonitorCardChips.spacing
        )
        #expect(MonitorCardChips.capacity(in: card) == 4)
        #expect(
            MonitorCardChips.capacity(
                in: card,
                reservingMarker: true
            ) == 2
        )
        let split = MonitorCardChips.split(Array(0..<5), in: card)
        #expect(split.shown.count == 2)
        #expect(split.overflow == 3)
        #expect(split.shown.count + split.overflow == 5)
    }
}
