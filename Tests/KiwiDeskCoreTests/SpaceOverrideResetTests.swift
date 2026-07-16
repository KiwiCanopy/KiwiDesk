import Foundation
import Testing

@testable import KiwiDeskCore

/// Per-space layout-override count, dormant detection, and the two
/// reset scopes (#290). The GUI's `Overrides…` count, dormant
/// disclosure, and reset buttons all read these, so they carry the
/// behavior tests rather than the SwiftUI views.
@Suite("Per-space override reset & count (#290)")
struct SpaceOverrideResetTests {
    private let space = SpaceID("2")

    /// A settings value with an override under three layouts for
    /// `space`, one field each — plus a gap override, which is a
    /// per-space setting but NOT a layout override.
    private func populated() -> TilingSettings {
        var s = TilingSettings()
        var bsp = BspOverride()
        bsp.splitRatioH = 0.7
        s.bsp.override[space] = bsp
        var stack = StackOverride()
        stack.masterCount = 3
        s.stack.override[space] = stack
        var scroll = ScrollingOverride()
        scroll.slotSize = .points(300)
        s.scrolling.override[space] = scroll
        s.gapsOverride[space] = .uniform(6)
        return s
    }

    @Test("Field count sums every layout for the space")
    func totalCount() {
        let s = populated()
        #expect(s.overrideFieldCount(for: space) == 3)
        #expect(s.overrideFieldCount(.bsp, for: space) == 1)
        #expect(s.overrideFieldCount(.grid, for: space) == 0)
        // A gap override is not a layout override — never counted.
        #expect(s.overrideFieldCount(for: SpaceID("nope")) == 0)
    }

    @Test("Dormant list excludes the active layout")
    func dormant() {
        let s = populated()
        // Active = bsp → stack + scrolling are dormant.
        let fromBsp = s.dormantOverrides(for: space, active: .bsp)
        #expect(fromBsp.map(\.mode) == [.stack, .scrolling])
        #expect(fromBsp.allSatisfy { $0.count == 1 })
        // Active = grid (no override here) → all three dormant.
        #expect(
            s.dormantOverrides(for: space, active: .grid).count == 3
        )
        // A space with nothing has no dormant layers.
        #expect(
            s.dormantOverrides(for: SpaceID("x"), active: .bsp)
                .isEmpty
        )
    }

    @Test("Reset one layer clears only that layout")
    func resetOne() {
        var s = populated()
        s.resetOverride(.bsp, for: space)
        #expect(s.bsp.override[space] == nil)
        // The other layers survive.
        #expect(s.stack.override[space] != nil)
        #expect(s.scrolling.override[space] != nil)
        #expect(s.overrideFieldCount(for: space) == 2)
    }

    @Test("Reset all clears every layer but keeps gap override")
    func resetAll() {
        var s = populated()
        s.resetAllLayoutOverrides(for: space)
        #expect(s.overrideFieldCount(for: space) == 0)
        #expect(s.bsp.override[space] == nil)
        #expect(s.stack.override[space] == nil)
        #expect(s.scrolling.override[space] == nil)
        // Gap override is not a layout override — reset leaves it.
        #expect(s.gapsOverride[space] == .uniform(6))
    }

    @Test("Reset is scoped to the one space")
    func resetScoped() {
        var s = populated()
        var other = BspOverride()
        other.splitRatioH = 0.4
        s.bsp.override[SpaceID("9")] = other
        s.resetAllLayoutOverrides(for: space)
        // The untargeted space keeps its override.
        #expect(s.bsp.override[SpaceID("9")] != nil)
    }
}

/// The slot-size override's three distinct non-inherit states plus
/// inheritance survive a profile round-trip (#290 acceptance).
@Suite("Scrolling slot-size override states (#290)")
struct SlotSizeOverrideStateTests {
    private func roundTrip(
        _ over: ScrollingOverride
    ) throws -> ScrollingOverride {
        let data = try JSONEncoder().encode(over)
        return try JSONDecoder().decode(
            ScrollingOverride.self,
            from: data
        )
    }

    @Test("Inherit (nil) stays absent and inert")
    func inherit() throws {
        let over = ScrollingOverride()  // slotSize == nil
        #expect(over.slotSize == nil)
        let data = try JSONEncoder().encode(over)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("slot_size"))
        #expect(try roundTrip(over).slotSize == nil)
    }

    @Test("Explicit Default is distinct from inherit")
    func explicitDefault() throws {
        var over = ScrollingOverride()
        over.slotSize = .auto
        // Not nil — an explicit orientation standard, not inherit.
        #expect(over.slotSize != nil)
        #expect(try roundTrip(over).slotSize == .auto)
    }

    @Test("Points and percent round-trip distinctly")
    func pointsAndPercent() throws {
        var pts = ScrollingOverride()
        pts.slotSize = .points(420)
        #expect(try roundTrip(pts).slotSize == .points(420))

        var pct = ScrollingOverride()
        pct.slotSize = .fraction(0.65)
        #expect(try roundTrip(pct).slotSize == .fraction(0.65))
    }
}
