import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Track per-space override (#128)")
struct TrackOverrideTests {
    /// `TrackParams` fields that are deliberately NOT per-space
    /// overridable. Anything else must be mirrored in
    /// `TrackOverride` — the reflection parity test below turns
    /// a forgotten mirror into a red build (AGENTS.md §5).
    private static let notOverridable: Set<String> = [
        // Per-layout behavior, not per-space geometry (the
        // ScrollingOverride precedent for wrapFocus).
        "newWindow",
        "wrapFocus",
        // The override map itself.
        "override",
    ]

    @Test("Every overridable TrackParams field is mirrored")
    func fieldParity() {
        let params = Set(
            Mirror(reflecting: TrackParams())
                .children.compactMap(\.label)
        )
        let mirror = Set(
            Mirror(reflecting: TrackOverride())
                .children.compactMap(\.label)
        )
        #expect(mirror == params.subtracting(Self.notOverridable))
    }

    @Test("Resolve applies every set field onto the global")
    func resolveAppliesAll() {
        var over = TrackOverride()
        over.axis = .horizontal
        over.count = 3
        let resolved = over.resolved(onto: TrackParams())
        #expect(resolved.axis == .horizontal)
        #expect(resolved.count == 3)
    }

    @Test("Unset fields inherit the global, per field")
    func partialInheritance() {
        var global = TrackParams()
        global.axis = .horizontal
        global.count = 2
        var over = TrackOverride()
        over.count = 5  // override only this
        let resolved = over.resolved(onto: global)
        #expect(resolved.count == 5)  // set
        #expect(resolved.axis == .horizontal)  // inherited
    }

    @Test("Sparse encode: only set fields, round-trips")
    func sparseRoundTrip() throws {
        var over = TrackOverride()
        over.count = 4
        let data = try JSONEncoder().encode(over)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("count"))
        #expect(!json.contains("axis"))
        let back = try JSONDecoder().decode(
            TrackOverride.self,
            from: data
        )
        #expect(back == over)
    }

    @Test("An empty override is sparse and inert")
    func emptyIsInert() throws {
        let over = TrackOverride()
        #expect(over.isEmpty)
        let data = try JSONEncoder().encode(over)
        #expect(String(data: data, encoding: .utf8) == "{}")
        #expect(
            over.resolved(onto: TrackParams()) == TrackParams()
        )
    }

    @Test("TilingSettings resolves track per space")
    func settingsResolver() {
        var settings = TilingSettings()
        settings.track.count = 0
        var over = TrackOverride()
        over.count = 3
        settings.track.override[SpaceID("2")] = over
        #expect(settings.resolvedTrack(for: "2").count == 3)
        #expect(settings.resolvedTrack(for: "1").count == 0)
    }

    @Test("override map nests under layout.track and round-trips")
    func settingsJSONNesting() throws {
        var settings = TilingSettings()
        var over = TrackOverride()
        over.axis = .horizontal
        settings.track.override[SpaceID("3")] = over
        let data = try JSONEncoder().encode(settings)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"override\""))
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(back.track.override == settings.track.override)
    }
}
