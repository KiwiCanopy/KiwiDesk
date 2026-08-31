import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Bsp per-space override (#17)")
struct BspOverrideTests {
    /// `BspParams` fields that are deliberately NOT per-space
    /// overridable. Anything else must be mirrored in
    /// `BspOverride` — the reflection parity test below turns a
    /// forgotten mirror into a red build (AGENTS.md §5).
    private static let notOverridable: Set<String> = [
        // Already per-space via new_window_placement_override.
        "newWindowPlacement",
        // The override map itself.
        "override",
    ]

    @Test("Every overridable BspParams field is mirrored")
    func fieldParity() {
        let params = Set(
            Mirror(reflecting: BspParams())
                .children.compactMap(\.label)
        )
        let mirror = Set(
            Mirror(reflecting: BspOverride())
                .children.compactMap(\.label)
        )
        #expect(mirror == params.subtracting(Self.notOverridable))
    }

    @Test("Resolve applies every set field onto the global")
    func resolveAppliesAll() {
        var over = BspOverride()
        over.strategy = .alternating
        over.splitRatioH = 0.7
        over.splitRatioV = 0.25
        let resolved = over.resolved(onto: BspParams())
        #expect(resolved.strategy == .alternating)
        #expect(resolved.splitRatioH == 0.7)
        #expect(resolved.splitRatioV == 0.25)
    }

    @Test("Unset fields inherit the global, per field")
    func partialInheritance() {
        var global = BspParams()
        global.strategy = .alternating
        global.splitRatioH = 0.3
        global.splitRatioV = 0.8
        var over = BspOverride()
        over.strategy = .longestSide  // override only this
        let resolved = over.resolved(onto: global)
        #expect(resolved.strategy == .longestSide)  // overridden
        #expect(resolved.splitRatioH == 0.3)  // inherited
        #expect(resolved.splitRatioV == 0.8)  // inherited
    }

    @Test("Sparse encode: only set fields, round-trips")
    func sparseRoundTrip() throws {
        var over = BspOverride()
        over.splitRatioH = 0.7
        let data = try JSONEncoder().encode(over)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("ratio_h"))
        #expect(!json.contains("ratio_v"))
        #expect(!json.contains("strategy"))
        let back = try JSONDecoder().decode(
            BspOverride.self,
            from: data
        )
        #expect(back == over)
    }

    @Test("An empty override is sparse and inert")
    func emptyIsInert() throws {
        let over = BspOverride()
        #expect(over.isEmpty)
        let data = try JSONEncoder().encode(over)
        #expect(String(data: data, encoding: .utf8) == "{}")
        #expect(over.resolved(onto: BspParams()) == BspParams())
    }

    @Test("TilingSettings resolves bsp per space")
    func settingsResolver() {
        var settings = TilingSettings()
        settings.bsp.strategy = .longestSide
        var over = BspOverride()
        over.strategy = .alternating
        settings.bsp.override[SpaceID("2")] = over
        #expect(
            settings.resolvedBsp(for: "2").strategy == .alternating
        )
        #expect(
            settings.resolvedBsp(for: "1").strategy == .longestSide
        )
    }

    @Test("override map nests under layout.bsp and round-trips")
    func settingsJSONNesting() throws {
        var settings = TilingSettings()
        var over = BspOverride()
        over.splitRatioH = 0.75
        settings.bsp.override[SpaceID("3")] = over
        let data = try JSONEncoder().encode(settings)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"override\""))
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(back.bsp.override == settings.bsp.override)
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

@Suite("bsp.set_*_override (per-space, #17)", .serialized)
@MainActor
struct BspOverrideCommandTests {
    @Test("strategy override writes only that space")
    func strategyOverride() {
        let core = makeCore()
        // Pin the global the untouched-space assertions read
        // (#660), and pin it AWAY from the value the override
        // writes: with both on the default the test cannot tell
        // "only that space" from "every space" (#1181).
        core.tiler.settings.bsp.strategy = .longestSide
        #expect(
            core.execute(
                "bsp.set_strategy_override",
                args: [.string("2"), .string("alternating")]
            ).isSuccess
        )
        let over = core.tiler.settings.bsp.override[SpaceID("2")]
        #expect(over?.strategy == .alternating)
        // The global params are untouched.
        #expect(core.tiler.settings.bsp.strategy == .longestSide)
        // Resolution reflects it for that space only.
        #expect(
            core.tiler.settings.resolvedBsp(for: "2").strategy
                == .alternating
        )
        #expect(
            core.tiler.settings.resolvedBsp(for: "1").strategy
                == .longestSide
        )
    }

    @Test("ratio overrides share the global clamp, per axis")
    func ratioOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "bsp.set_ratio_h_override",
                args: [.string("7"), .number(2)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "bsp.set_ratio_v_override",
                args: [.string("7"), .number(0.2)]
            ).isSuccess
        )
        let over = core.tiler.settings.bsp.override[SpaceID("7")]
        #expect(over?.splitRatioH == 0.9)  // clamped ceiling
        #expect(over?.splitRatioV == 0.2)
    }

    @Test("Invalid value is rejected and writes nothing")
    func invalidRejected() {
        let core = makeCore()
        #expect(
            !core.execute(
                "bsp.set_strategy_override",
                args: [.string("2"), .string("diagonal")]
            ).isSuccess
        )
        #expect(core.tiler.settings.bsp.override.isEmpty)
        // Missing value is rejected too.
        #expect(
            !core.execute(
                "bsp.set_strategy_override",
                args: [.string("alternating")]
            ).isSuccess
        )
    }
}
