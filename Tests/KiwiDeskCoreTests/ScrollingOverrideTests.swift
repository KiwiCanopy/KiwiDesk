import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Scrolling per-space override (#17)")
struct ScrollingOverrideTests {
    /// `ScrollingParams` fields that are deliberately NOT
    /// per-space overridable. Anything else must be mirrored in
    /// `ScrollingOverride` — the reflection parity test below
    /// turns a forgotten mirror into a red build (AGENTS.md §5).
    private static let notOverridable: Set<String> = [
        // Already per-space via new_window_placement_override.
        "newWindowPlacement",
        // Per-space bar *look* lands with the app-bar tier.
        "appBar",
        // The override map itself.
        "override",
    ]

    @Test("Every overridable ScrollingParams field is mirrored")
    func fieldParity() {
        let params = Set(
            Mirror(reflecting: ScrollingParams())
                .children.compactMap(\.label)
        )
        let mirror = Set(
            Mirror(reflecting: ScrollingOverride())
                .children.compactMap(\.label)
        )
        // Add a tunable field to ScrollingParams without
        // mirroring it here (or marking it not-overridable) and
        // this fails — the guard discovers fields, never a hand
        // list that can itself drift.
        #expect(mirror == params.subtracting(Self.notOverridable))
    }

    @Test("Resolve applies every set field onto the global")
    func resolveAppliesAll() {
        var over = ScrollingOverride()
        over.slotSize = .points(320)
        over.anchor = .right
        over.orientation = .vertical
        let resolved = over.resolved(onto: ScrollingParams())
        #expect(resolved.slotSize == .points(320))
        #expect(resolved.anchor == .right)
        #expect(resolved.orientation == .vertical)
    }

    @Test("Unset fields inherit the global, per field")
    func partialInheritance() {
        var global = ScrollingParams()
        global.slotSize = .points(150)
        global.anchor = .left
        global.orientation = .horizontal
        var over = ScrollingOverride()
        over.orientation = .vertical  // override only this
        let resolved = over.resolved(onto: global)
        #expect(resolved.orientation == .vertical)  // overridden
        #expect(resolved.anchor == .left)  // inherited
        #expect(resolved.slotSize == .points(150))  // inherited
    }

    @Test("Sparse encode: only set fields, round-trips")
    func sparseRoundTrip() throws {
        var over = ScrollingOverride()
        over.orientation = .vertical
        let data = try JSONEncoder().encode(over)
        let json =
            try #require(String(data: data, encoding: .utf8))
        // Only the set field is present.
        #expect(json.contains("orientation"))
        #expect(!json.contains("slot_size"))
        #expect(!json.contains("anchor"))
        let back = try JSONDecoder().decode(
            ScrollingOverride.self,
            from: data
        )
        #expect(back == over)
    }

    @Test("An empty override is sparse and inert")
    func emptyIsInert() throws {
        let over = ScrollingOverride()
        #expect(over.isEmpty)
        let data = try JSONEncoder().encode(over)
        #expect(String(data: data, encoding: .utf8) == "{}")
        #expect(
            over.resolved(onto: ScrollingParams())
                == ScrollingParams()
        )
    }

    @Test("TilingSettings resolves scrolling per space")
    func settingsResolver() {
        var settings = TilingSettings()
        settings.scrolling.orientation = .horizontal
        var over = ScrollingOverride()
        over.orientation = .vertical
        settings.scrolling.override[SpaceID("2")] = over
        // Overridden space flips; others keep the global.
        #expect(
            settings.resolvedScrolling(for: "2").orientation
                == .vertical
        )
        #expect(
            settings.resolvedScrolling(for: "1").orientation
                == .horizontal
        )
    }

    @Test("resolved params never carry the per-space override map")
    func resolvedDropsOverrideMap() {
        var s = TilingSettings()
        var scroll = ScrollingOverride()
        scroll.orientation = .vertical
        s.scrolling.override[SpaceID("1")] = scroll
        var bsp = BspOverride()
        bsp.splitRatioH = 0.7
        s.bsp.override[SpaceID("1")] = bsp
        var stack = StackOverride()
        stack.masterCount = 3
        s.stack.override[SpaceID("1")] = stack
        var grid = GridOverride()
        grid.columns = 4
        s.grid.override[SpaceID("1")] = grid
        var mono = MonocleOverride()
        mono.orientation = .vertical
        s.monocle.override[SpaceID("1")] = mono
        // Both the overridden space and an unoverridden one must
        // resolve to params with an empty override map — a
        // forgotten `out.override = [:]` in any family (either
        // resolve branch) fails here (guards the m3b invariant).
        for space in [SpaceID("1"), SpaceID("2")] {
            #expect(s.resolvedScrolling(for: space).override.isEmpty)
            #expect(s.resolvedBsp(for: space).override.isEmpty)
            #expect(s.resolvedStack(for: space).override.isEmpty)
            #expect(s.resolvedGrid(for: space).override.isEmpty)
            #expect(s.resolvedMonocle(for: space).override.isEmpty)
        }
    }

    @Test("override map nests under layout.scroll and round-trips")
    func settingsJSONNesting() throws {
        var settings = TilingSettings()
        var over = ScrollingOverride()
        over.slotSize = .points(250)
        settings.scrolling.override[SpaceID("3")] = over
        let data = try JSONEncoder().encode(settings)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"override\""))
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(back.scrolling.override == settings.scrolling.override)
    }
}
