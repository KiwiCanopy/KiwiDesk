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

    /// Two rows' worth, one chip over: four shown, two behind the
    /// marker — the general case of the same arithmetic.
    @Test("one chip over capacity hides two")
    func oneOverHidesTwo() {
        let card = CGSize(
            width: floor.width + MonitorCardChips.minChipWidth
                + MonitorCardChips.spacing,
            height: floor.height + MonitorCardChips.chipHeight
                + MonitorCardChips.spacing
        )
        #expect(MonitorCardChips.capacity(in: card) == 4)
        let split = MonitorCardChips.split(Array(0..<5), in: card)
        #expect(split.shown.count == 3)
        #expect(split.overflow == 2)
        #expect(split.shown.count + split.overflow == 5)
    }
}
