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
        // Auto is 95% of the available along-axis on both
        // orientations.
        #expect(
            ScrollSize.auto.resolved(along: 2000, horizontal: true)
                == 1900
        )
        #expect(
            ScrollSize.auto.resolved(along: 1000, horizontal: true)
                == 950
        )
        #expect(
            ScrollSize.auto.resolved(along: 1000, horizontal: false)
                == 950
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
                == 1900
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
    return makeTestCore(configDirectory: directory)
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
    @Test("accepts center | start | end | follow (#239)")
    func canonicalAnchors() {
        let core = makeCore()
        let cases: [(String, ScrollingParams.Anchor)] = [
            ("center", .center),
            ("start", .start),
            ("end", .end),
            ("follow", .follow),
        ]
        for (raw, value) in cases {
            #expect(
                core.execute(
                    "scroll.set_anchor",
                    args: [.string(raw)]
                ).isSuccess
            )
            #expect(core.tiler.settings.scrolling.anchor == value)
        }
    }

    @Test("rejects the old compass spellings (#239)")
    func rejectsCompassSpellings() {
        let core = makeCore()
        for raw in ["left", "right", "top", "bottom"] {
            #expect(
                !core.execute(
                    "scroll.set_anchor",
                    args: [.string(raw)]
                ).isSuccess
            )
        }
    }
}

@Suite("scroll.set_*_override (per-space, #17)", .serialized)
@MainActor
struct ScrollOverrideCommandTests {
    @Test("orientation override writes only that space")
    func orientationOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "scroll.set_orientation_override",
                args: [.string("2"), .string("vertical")]
            ).isSuccess
        )
        let over =
            core.tiler.settings.scrolling.override[SpaceID("2")]
        #expect(over?.orientation == .vertical)
        // The global params are untouched.
        #expect(
            core.tiler.settings.scrolling.orientation
                == .horizontal
        )
        // Resolution reflects it for that space only.
        #expect(
            core.tiler.settings.resolvedScrolling(for: "2")
                .orientation == .vertical
        )
        #expect(
            core.tiler.settings.resolvedScrolling(for: "1")
                .orientation == .horizontal
        )
    }

    @Test("slot_size + anchor overrides share the global parsers")
    func slotAndAnchorOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "scroll.set_slot_size_override",
                args: [.string("7"), .number(50)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "scroll.set_anchor_override",
                args: [.string("7"), .string("end")]
            ).isSuccess
        )
        let over =
            core.tiler.settings.scrolling.override[SpaceID("7")]
        // Same clamp/parsing as the global setters.
        #expect(over?.slotSize == .points(100))  // clamped floor
        #expect(over?.anchor == .end)
    }

    @Test("Invalid value is rejected and writes nothing")
    func invalidRejected() {
        let core = makeCore()
        #expect(
            !core.execute(
                "scroll.set_orientation_override",
                args: [.string("2"), .string("sideways")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.scrolling.override.isEmpty
        )
        // Missing space id is rejected too.
        #expect(
            !core.execute(
                "scroll.set_orientation_override",
                args: [.string("vertical")]
            ).isSuccess
        )
    }
}
