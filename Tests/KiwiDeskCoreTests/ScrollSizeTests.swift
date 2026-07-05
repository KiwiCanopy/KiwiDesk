import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Encode through an array so the single-value payload is never a
/// top-level JSON fragment.
private func roundTrip(_ size: ScrollSize) throws -> ScrollSize {
    let data = try JSONEncoder().encode([size])
    return try JSONDecoder().decode([ScrollSize].self, from: data)[0]
}

private func decode(_ json: String) throws -> ScrollSize {
    try JSONDecoder().decode(
        [ScrollSize].self,
        from: Data(json.utf8)
    )[0]
}

@Suite("ScrollSize")
struct ScrollSizeTests {
    @Test("Codable round-trips every case")
    func roundTrips() throws {
        #expect(try roundTrip(.auto) == .auto)
        #expect(try roundTrip(.points(400)) == .points(400))
        #expect(try roundTrip(.fraction(0.8)) == .fraction(0.8))
        // Half-percent survives exactly (no integer truncation).
        #expect(try roundTrip(.fraction(0.335)) == .fraction(0.335))
    }

    @Test("Decode maps the JSON vocabulary")
    func decodeVocabulary() throws {
        #expect(try decode("[0]") == .auto)
        #expect(try decode("[900]") == .points(900))
        #expect(try decode("[\"80%\"]") == .fraction(0.8))
    }

    @Test("Decode is total — junk and out-of-range normalize")
    func decodeTolerant() throws {
        // Non-percent / malformed strings fall back to auto.
        #expect(try decode("[\"50pt\"]") == .auto)
        #expect(try decode("[\"big\"]") == .auto)
        // Zero / negative numbers → auto.
        #expect(try decode("[-5]") == .auto)
        // Out-of-range percents clamp to the fraction bounds.
        #expect(try decode("[\"150%\"]") == .fraction(1))
        #expect(try decode("[\"1%\"]") == .fraction(0.05))
    }

    @Test("percentString is exact to a half percent")
    func percentStrings() {
        #expect(ScrollSize.percentString(0.8) == "80%")
        #expect(ScrollSize.percentString(0.5) == "50%")
        #expect(ScrollSize.percentString(0.335) == "33.5%")
    }

    @Test("Clamping factories enforce one floor/ceiling")
    func clampingFactories() {
        #expect(ScrollSize.points(clamping: 50) == .points(100))
        #expect(ScrollSize.points(clamping: 500) == .points(500))
        #expect(ScrollSize.fraction(clamping: 2) == .fraction(1))
        #expect(
            ScrollSize.fraction(clamping: 0.01) == .fraction(0.05)
        )
    }

    @Test("resolved clamps to the along-axis")
    func resolvedClamps() {
        // Horizontal auto is a fixed pt, clamped when the axis is
        // shorter than the standard.
        #expect(
            ScrollSize.auto.resolved(along: 2000, horizontal: true)
                == 1100
        )
        #expect(
            ScrollSize.auto.resolved(along: 1000, horizontal: true)
                == 1000
        )
        // Vertical auto is 80% of the available along-axis.
        #expect(
            ScrollSize.auto.resolved(along: 1000, horizontal: false)
                == 800
        )
        #expect(
            ScrollSize.fraction(0.5)
                .resolved(along: 1000, horizontal: false) == 500
        )
        #expect(
            ScrollSize.points(3000)
                .resolved(along: 1000, horizontal: true) == 1000
        )
    }

    @Test("editablePoints keeps explicit points unclamped")
    func editablePointsUnclamped() {
        // A stored pt is never rewritten by the along-axis — this
        // is what stops resize from silently shrinking a big slot.
        #expect(
            ScrollSize.points(3000)
                .editablePoints(along: 1000, horizontal: true)
                == 3000
        )
        // auto / fraction still seed against the axis.
        #expect(
            ScrollSize.auto
                .editablePoints(along: 2000, horizontal: true)
                == 1100
        )
        #expect(
            ScrollSize.fraction(0.5)
                .editablePoints(along: 1000, horizontal: false)
                == 500
        )
    }
}

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

@Suite("scroll.set_slot_size", .serialized)
@MainActor
struct ScrollSlotSizeCommandTests {
    @Test("A number sets points, clamped to the floor")
    func numberSetsPoints() {
        let core = makeCore()
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.number(900)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.slotSize == .points(900)
        )
        // Below the floor clamps up.
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.number(50)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.slotSize == .points(100)
        )
    }

    @Test("Zero sets auto")
    func zeroSetsAuto() {
        let core = makeCore()
        core.tiler.settings.scrolling.slotSize = .points(400)
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.number(0)]
            ).isSuccess
        )
        #expect(core.tiler.settings.scrolling.slotSize == .auto)
    }

    @Test("A \"NN%\" string sets a fraction")
    func percentSetsFraction() {
        let core = makeCore()
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.string("80%")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.slotSize
                == .fraction(0.8)
        )
    }

    @Test("An unparseable value fails")
    func invalidFails() {
        let core = makeCore()
        #expect(
            !core.execute(
                "scroll.set_slot_size",
                args: [.string("huge")]
            ).isSuccess
        )
    }
}

@Suite("scroll.set_anchor", .serialized)
@MainActor
struct ScrollAnchorCommandTests {
    @Test("top / bottom alias to left / right (vertical spelling)")
    func verticalAnchorAliases() {
        let core = makeCore()
        #expect(
            core.execute(
                "scroll.set_anchor",
                args: [.string("top")]
            ).isSuccess
        )
        #expect(core.tiler.settings.scrolling.anchor == .left)
        #expect(
            core.execute(
                "scroll.set_anchor",
                args: [.string("bottom")]
            ).isSuccess
        )
        #expect(core.tiler.settings.scrolling.anchor == .right)
        // The canonical spellings still work.
        #expect(
            core.execute(
                "scroll.set_anchor",
                args: [.string("center")]
            ).isSuccess
        )
        #expect(core.tiler.settings.scrolling.anchor == .center)
    }
}
