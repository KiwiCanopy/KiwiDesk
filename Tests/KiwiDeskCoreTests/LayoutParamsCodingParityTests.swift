import Foundation
import Testing

@testable import KiwiDeskCore

/// Forget-proof coverage for each layout params struct's manual
/// sparse `Codable` (#73). Every struct hand-writes `CodingKeys`,
/// `init(from:)`, and `encode(to:)`; a field dropped from any of
/// the three silently round-trips to its default. Each test pairs
/// two nets: `expectAllChanged` (reflection) forces the fixture to
/// touch every field, and the JSON round-trip then proves each of
/// those fields survives decode ↔ encode ↔ CodingKeys. A new field
/// left unset trips the first; a forgotten Codable line trips the
/// second (AGENTS.md §5).
@Suite("Layout params sparse Codable parity")
struct LayoutParamsCodingParityTests {
    @Test("BspParams round-trips every field")
    func bsp() throws {
        try expectRoundTrips(Self.bsp(), from: BspParams())
    }

    @Test("StackParams round-trips every field")
    func stack() throws {
        try expectRoundTrips(Self.stack(), from: StackParams())
    }

    @Test("GridParams round-trips every field")
    func grid() throws {
        try expectRoundTrips(Self.grid(), from: GridParams())
    }

    @Test("ScrollingParams round-trips every field")
    func scrolling() throws {
        try expectRoundTrips(
            Self.scrolling(),
            from: ScrollingParams()
        )
    }

    @Test("MonocleParams round-trips every field")
    func monocle() throws {
        try expectRoundTrips(
            Self.monocle(),
            from: MonocleParams()
        )
    }

    @Test("TrackParams round-trips every field")
    func track() throws {
        try expectRoundTrips(Self.track(), from: TrackParams())
    }

    @Test("Missing keys decode every params initializer default")
    func missingKeysUseDefaults() throws {
        try expectDefaults(BspParams())
        try expectDefaults(StackParams())
        try expectDefaults(GridParams())
        try expectDefaults(ScrollingParams())
        try expectDefaults(MonocleParams())
        try expectDefaults(TrackParams())
    }

    // MARK: Exhaustive fixtures (every field ≠ its default)

    private static let space = SpaceID("2")

    private func expectDefaults<T: Decodable & Equatable>(
        _ defaults: T
    ) throws {
        let decoded = try JSONDecoder().decode(
            T.self,
            from: Data("{}".utf8)
        )
        #expect(decoded == defaults)
    }

    private static func bsp() -> BspParams {
        var params = BspParams()
        params.strategy = .alternating
        params.splitRatioH = 0.75
        params.splitRatioV = 0.25
        params.newWindowPlacement = .last
        var over = BspOverride()
        over.splitRatioH = 0.4
        params.override[space] = over
        return params
    }

    private static func stack() -> StackParams {
        var params = StackParams()
        params.masterCount = 3
        params.masterRatio = 0.35
        params.overflowStyle = .cascadeAll
        params.masterOrientation = .vertical
        params.stackPosition = .top
        params.newWindowPlacement = .last
        var over = StackOverride()
        over.masterCount = 2
        params.override[space] = over
        return params
    }

    private static func grid() -> GridParams {
        var params = GridParams()
        params.type = .rigid
        params.fillEmptyCells = false
        params.splitDirection = .vertical
        params.columns = 5
        params.rows = 4
        params.autoSize = true
        params.newWindowPlacement = .first
        var over = GridOverride()
        over.columns = 6
        params.override[space] = over
        return params
    }

    private static func scrolling() -> ScrollingParams {
        var params = ScrollingParams()
        params.slotSize = .points(300)
        params.anchor = .start
        params.orientation = .vertical
        params.newWindowPlacement = .first
        params.wrapFocus = true
        params.appBar.enabled = false
        var over = ScrollingOverride()
        over.anchor = .end
        params.override[space] = over
        return params
    }

    private static func monocle() -> MonocleParams {
        var params = MonocleParams()
        params.orientation = .vertical
        params.wrapFocus = true
        params.newWindowPlacement = .last
        params.appBar.enabled = false
        var over = MonocleOverride()
        over.orientation = .horizontal
        params.override[space] = over
        return params
    }

    private static func track() -> TrackParams {
        var params = TrackParams()
        params.axis = .horizontal
        params.autoTracks = false
        params.limit = 4
        params.newWindow = .ownTrack
        params.newWindowPosition = .last
        params.overflowStyle = .cascadeOverflow
        params.wrapFocus = true
        var over = TrackOverride()
        over.limit = 2
        params.override[space] = over
        return params
    }
}
