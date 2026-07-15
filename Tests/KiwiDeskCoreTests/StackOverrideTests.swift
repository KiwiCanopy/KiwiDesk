import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Stack per-space override (#17)")
struct StackOverrideTests {
    /// `StackParams` fields that are deliberately NOT per-space
    /// overridable. Anything else must be mirrored in
    /// `StackOverride` — the reflection parity test below turns a
    /// forgotten mirror into a red build (AGENTS.md §5).
    private static let notOverridable: Set<String> = [
        // Already per-space via new_window_placement_override.
        "newWindowPlacement",
        // The override map itself.
        "override",
    ]

    @Test("Every overridable StackParams field is mirrored")
    func fieldParity() {
        let params = Set(
            Mirror(reflecting: StackParams())
                .children.compactMap(\.label)
        )
        let mirror = Set(
            Mirror(reflecting: StackOverride())
                .children.compactMap(\.label)
        )
        #expect(mirror == params.subtracting(Self.notOverridable))
    }

    @Test("Resolve applies every set field onto the global")
    func resolveAppliesAll() {
        var over = StackOverride()
        over.masterCount = 3
        over.masterRatio = 0.75
        over.overflowStyle = .cascadeAll
        over.masterOrientation = .horizontal
        over.stackPosition = .bottom
        let resolved = over.resolved(onto: StackParams())
        #expect(resolved.masterCount == 3)
        #expect(resolved.masterRatio == 0.75)
        #expect(resolved.overflowStyle == .cascadeAll)
        #expect(resolved.masterOrientation == .horizontal)
        #expect(resolved.stackPosition == .bottom)
    }

    @Test("Unset fields inherit the global, per field")
    func partialInheritance() {
        var global = StackParams()
        global.masterCount = 2
        global.masterRatio = 0.4
        global.overflowStyle = .cascadeOverflow
        var over = StackOverride()
        over.overflowStyle = .cascadeAll  // override only this
        let resolved = over.resolved(onto: global)
        #expect(resolved.overflowStyle == .cascadeAll)  // set
        #expect(resolved.masterCount == 2)  // inherited
        #expect(resolved.masterRatio == 0.4)  // inherited
    }

    @Test("Sparse encode: only set fields, round-trips")
    func sparseRoundTrip() throws {
        var over = StackOverride()
        over.masterRatio = 0.75
        let data = try JSONEncoder().encode(over)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("master_ratio"))
        #expect(!json.contains("master_count"))
        #expect(!json.contains("overflow_style"))
        let back = try JSONDecoder().decode(
            StackOverride.self,
            from: data
        )
        #expect(back == over)
    }

    @Test("An empty override is sparse and inert")
    func emptyIsInert() throws {
        let over = StackOverride()
        #expect(over.isEmpty)
        let data = try JSONEncoder().encode(over)
        #expect(String(data: data, encoding: .utf8) == "{}")
        #expect(
            over.resolved(onto: StackParams()) == StackParams()
        )
    }

    @Test("TilingSettings resolves stack per space")
    func settingsResolver() {
        var settings = TilingSettings()
        settings.stack.masterCount = 1
        var over = StackOverride()
        over.masterCount = 3
        settings.stack.override[SpaceID("2")] = over
        #expect(
            settings.resolvedStack(for: "2").masterCount == 3
        )
        #expect(
            settings.resolvedStack(for: "1").masterCount == 1
        )
    }

    @Test("override map nests under layout.stack and round-trips")
    func settingsJSONNesting() throws {
        var settings = TilingSettings()
        var over = StackOverride()
        over.masterRatio = 0.7
        settings.stack.override[SpaceID("3")] = over
        let data = try JSONEncoder().encode(settings)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"override\""))
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(back.stack.override == settings.stack.override)
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

@Suite("stack.set_*_override (per-space, #17)", .serialized)
@MainActor
struct StackOverrideCommandTests {
    @Test("master_count override writes only that space")
    func masterCountOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "stack.set_master_count_override",
                args: [.string("2"), .number(4)]
            ).isSuccess
        )
        let over = core.tiler.settings.stack.override[SpaceID("2")]
        #expect(over?.masterCount == 4)
        // The global params are untouched.
        #expect(core.tiler.settings.stack.masterCount == 1)
        #expect(
            core.tiler.settings.resolvedStack(for: "2").masterCount
                == 4
        )
        #expect(
            core.tiler.settings.resolvedStack(for: "1").masterCount
                == 1
        )
    }

    @Test("ratio + style overrides share the global parsers")
    func ratioAndStyleOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "stack.set_master_ratio_override",
                args: [.string("7"), .number(2)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "stack.set_overflow_style_override",
                args: [.string("7"), .string("cascade_all")]
            ).isSuccess
        )
        let over = core.tiler.settings.stack.override[SpaceID("7")]
        #expect(over?.masterRatio == 0.9)  // clamped ceiling
        #expect(over?.overflowStyle == .cascadeAll)
    }

    @Test("Invalid value is rejected and writes nothing")
    func invalidRejected() {
        let core = makeCore()
        #expect(
            !core.execute(
                "stack.set_overflow_style_override",
                args: [.string("2"), .string("cascade_none")]
            ).isSuccess
        )
        #expect(core.tiler.settings.stack.override.isEmpty)
        // Missing value is rejected too.
        #expect(
            !core.execute(
                "stack.set_master_count_override",
                args: [.string("2")]
            ).isSuccess
        )
    }
}
