import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Grid per-space override (#17)")
struct GridOverrideTests {
    /// `GridParams` fields that are deliberately NOT per-space
    /// overridable. Anything else must be mirrored in
    /// `GridOverride` — the reflection parity test below turns a
    /// forgotten mirror into a red build (AGENTS.md §5).
    private static let notOverridable: Set<String> = [
        // Already per-space via new_window_placement_override.
        "newWindowPlacement",
        // The override map itself.
        "override",
    ]

    @Test("Every overridable GridParams field is mirrored")
    func fieldParity() {
        let params = Set(
            Mirror(reflecting: GridParams())
                .children.compactMap(\.label)
        )
        let mirror = Set(
            Mirror(reflecting: GridOverride())
                .children.compactMap(\.label)
        )
        #expect(mirror == params.subtracting(Self.notOverridable))
    }

    @Test("Resolve applies every set field onto the global")
    func resolveAppliesAll() {
        var over = GridOverride()
        over.type = .rigid
        over.fillEmptyCells = false
        over.splitDirection = .vertical
        over.columns = 5
        over.rows = 4
        over.autoSize = true
        let resolved = over.resolved(onto: GridParams())
        #expect(resolved.type == .rigid)
        #expect(resolved.fillEmptyCells == false)
        #expect(resolved.splitDirection == .vertical)
        #expect(resolved.columns == 5)
        #expect(resolved.rows == 4)
        #expect(resolved.autoSize == true)
    }

    @Test("Unset fields inherit the global, per field")
    func partialInheritance() {
        var global = GridParams()
        global.type = .dynamic
        global.columns = 3
        global.rows = 2
        var over = GridOverride()
        over.type = .rigid  // override only this
        let resolved = over.resolved(onto: global)
        #expect(resolved.type == .rigid)  // overridden
        #expect(resolved.columns == 3)  // inherited
        #expect(resolved.rows == 2)  // inherited
    }

    @Test("Sparse encode: only set fields, round-trips")
    func sparseRoundTrip() throws {
        var over = GridOverride()
        over.splitDirection = .vertical
        let data = try JSONEncoder().encode(over)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("split_direction"))
        #expect(!json.contains("fill_empty_cells"))
        #expect(!json.contains("columns"))
        let back = try JSONDecoder().decode(
            GridOverride.self,
            from: data
        )
        #expect(back == over)
    }

    @Test("An empty override is sparse and inert")
    func emptyIsInert() throws {
        let over = GridOverride()
        #expect(over.isEmpty)
        let data = try JSONEncoder().encode(over)
        #expect(String(data: data, encoding: .utf8) == "{}")
        #expect(over.resolved(onto: GridParams()) == GridParams())
    }

    @Test("TilingSettings resolves grid per space")
    func settingsResolver() {
        var settings = TilingSettings()
        settings.grid.type = .dynamic
        var over = GridOverride()
        over.type = .rigid
        settings.grid.override[SpaceID("2")] = over
        #expect(settings.resolvedGrid(for: "2").type == .rigid)
        #expect(settings.resolvedGrid(for: "1").type == .dynamic)
    }

    @Test("override map nests under layout.grid and round-trips")
    func settingsJSONNesting() throws {
        var settings = TilingSettings()
        var over = GridOverride()
        over.columns = 6
        over.rows = 3
        settings.grid.override[SpaceID("3")] = over
        let data = try JSONEncoder().encode(settings)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"override\""))
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(back.grid.override == settings.grid.override)
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

@Suite("grid.set_*_override (per-space, #17)", .serialized)
@MainActor
struct GridOverrideCommandTests {
    @Test("type override writes only that space")
    func typeOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "grid.set_type_override",
                args: [.string("2"), .string("rigid")]
            ).isSuccess
        )
        let over = core.tiler.settings.grid.override[SpaceID("2")]
        #expect(over?.type == .rigid)
        // The global params are untouched.
        #expect(core.tiler.settings.grid.type == .dynamic)
        #expect(
            core.tiler.settings.resolvedGrid(for: "2").type
                == .rigid
        )
        #expect(
            core.tiler.settings.resolvedGrid(for: "1").type
                == .dynamic
        )
    }

    @Test("dimensions override sets columns + rows, floored")
    func dimensionsOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "grid.set_dimensions_override",
                args: [.string("7"), .number(5), .number(0)]
            ).isSuccess
        )
        let over = core.tiler.settings.grid.override[SpaceID("7")]
        #expect(over?.columns == 5)
        #expect(over?.rows == 1)  // 0 floored to 1
        // The global dimensions are untouched.
        #expect(core.tiler.settings.grid.columns == 3)
        #expect(core.tiler.settings.grid.rows == 2)
    }

    @Test("auto_size override writes only that space")
    func autoSizeOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "grid.set_auto_size_override",
                args: [.string("4"), .bool(true)]
            ).isSuccess
        )
        let over = core.tiler.settings.grid.override[SpaceID("4")]
        #expect(over?.autoSize == true)
        // Global stays off.
        #expect(core.tiler.settings.grid.autoSize == false)
        #expect(
            core.tiler.settings.resolvedGrid(for: "4").autoSize
        )
    }

    @Test("global auto_size sets the flag")
    func autoSizeGlobal() {
        let core = makeCore()
        #expect(
            core.execute(
                "grid.set_auto_size",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.grid.autoSize == true)
    }

    @Test("Invalid value is rejected and writes nothing")
    func invalidRejected() {
        let core = makeCore()
        #expect(
            !core.execute(
                "grid.set_type_override",
                args: [.string("2"), .string("hexagonal")]
            ).isSuccess
        )
        #expect(core.tiler.settings.grid.override.isEmpty)
        // Missing second dimension is rejected too.
        #expect(
            !core.execute(
                "grid.set_dimensions_override",
                args: [.string("2"), .number(4)]
            ).isSuccess
        )
    }
}
