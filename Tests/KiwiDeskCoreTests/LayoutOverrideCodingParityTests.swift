import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Forget-proof coverage for the five per-space `*Override`
/// structs (#17), brought up to the same standard as the params
/// structs they mirror (#73 audit). Each hand-writes an optional
/// mirror, a per-field `resolved(onto:)`, and a manual sparse
/// `Codable`.
///
/// The property mirror itself is already guarded by each struct's
/// `fieldParity` reflection test (the #17 template). What that net
/// does *not* reach — a forgotten `encode`/`decode` line or a
/// forgotten `if let` in `resolved(onto:)` — is closed here:
/// `expectRoundTrips` pins the sparse Codable (exhaustive fixture
/// + round-trip), and `expectResolvesEveryField` pins the merge.
/// Each fixture sets every override field to a value that also
/// differs from the params default, so resolving onto the default
/// exercises every branch.
@Suite("Layout override forget-proof parity")
struct LayoutOverrideCodingParityTests {
    @Test("BspOverride round-trips and resolves every field")
    func bsp() throws {
        let over = Self.bsp()
        try expectRoundTrips(over, from: BspOverride())
        expectResolvesEveryField(
            resolved: over.resolved(onto: BspParams()),
            base: BspParams(),
            covered: fieldNames(BspOverride())
        )
    }

    @Test("StackOverride round-trips and resolves every field")
    func stack() throws {
        let over = Self.stack()
        try expectRoundTrips(over, from: StackOverride())
        expectResolvesEveryField(
            resolved: over.resolved(onto: StackParams()),
            base: StackParams(),
            covered: fieldNames(StackOverride())
        )
    }

    @Test("GridOverride round-trips and resolves every field")
    func grid() throws {
        let over = Self.grid()
        try expectRoundTrips(over, from: GridOverride())
        expectResolvesEveryField(
            resolved: over.resolved(onto: GridParams()),
            base: GridParams(),
            covered: fieldNames(GridOverride())
        )
    }

    @Test("ScrollingOverride round-trips and resolves every field")
    func scrolling() throws {
        let over = Self.scrolling()
        try expectRoundTrips(over, from: ScrollingOverride())
        expectResolvesEveryField(
            resolved: over.resolved(onto: ScrollingParams()),
            base: ScrollingParams(),
            covered: fieldNames(ScrollingOverride())
        )
    }

    @Test("MonocleOverride round-trips and resolves every field")
    func monocle() throws {
        let over = Self.monocle()
        try expectRoundTrips(over, from: MonocleOverride())
        expectResolvesEveryField(
            resolved: over.resolved(onto: MonocleParams()),
            base: MonocleParams(),
            covered: fieldNames(MonocleOverride())
        )
    }

    @Test("TrackOverride round-trips and resolves every field")
    func track() throws {
        let over = Self.track()
        try expectRoundTrips(over, from: TrackOverride())
        expectResolvesEveryField(
            resolved: over.resolved(onto: TrackParams()),
            base: TrackParams(),
            covered: fieldNames(TrackOverride())
        )
    }

    // MARK: Exhaustive fixtures (every field set, ≠ its default)

    private static func track() -> TrackOverride {
        var over = TrackOverride()
        over.axis = .horizontal
        over.count = 3
        over.overflowStyle = .cascadeAll
        return over
    }

    private static func bsp() -> BspOverride {
        var over = BspOverride()
        over.strategy = .alternating
        over.splitRatioH = 0.7
        over.splitRatioV = 0.35
        return over
    }

    private static func stack() -> StackOverride {
        var over = StackOverride()
        over.masterCount = 4
        over.masterRatio = 0.3
        over.overflowStyle = .cascadeAll
        return over
    }

    private static func grid() -> GridOverride {
        var over = GridOverride()
        over.type = .rigid
        over.fillEmptySpace = false
        over.splitDirection = .vertical
        over.columns = 7
        over.rows = 5
        over.autoSize = true
        return over
    }

    private static func scrolling() -> ScrollingOverride {
        var over = ScrollingOverride()
        over.slotSize = .points(250)
        over.anchor = .left
        over.orientation = .vertical
        return over
    }

    private static func monocle() -> MonocleOverride {
        var over = MonocleOverride()
        over.orientation = .vertical
        return over
    }
}
