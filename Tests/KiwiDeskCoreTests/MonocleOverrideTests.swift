import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Monocle per-space override (#17)")
struct MonocleOverrideTests {
    /// `MonocleParams` fields that are deliberately NOT per-space
    /// overridable. Anything else must be mirrored in
    /// `MonocleOverride` — the reflection parity test below turns a
    /// forgotten mirror into a red build (AGENTS.md §5).
    private static let notOverridable: Set<String> = [
        // Per-space bar *look* lands with the app-bar tier; only
        // the orientation (which drives the bar edge) is per-space.
        "appBar",
        // The override map itself.
        "override",
    ]

    @Test("Every overridable MonocleParams field is mirrored")
    func fieldParity() {
        let params = Set(
            Mirror(reflecting: MonocleParams())
                .children.compactMap(\.label)
        )
        let mirror = Set(
            Mirror(reflecting: MonocleOverride())
                .children.compactMap(\.label)
        )
        #expect(mirror == params.subtracting(Self.notOverridable))
    }

    @Test("Resolve applies every set field onto the global")
    func resolveAppliesAll() {
        var over = MonocleOverride()
        over.orientation = .vertical
        let resolved = over.resolved(onto: MonocleParams())
        #expect(resolved.orientation == .vertical)
    }

    @Test("Unset fields inherit the global, per field")
    func partialInheritance() {
        var global = MonocleParams()
        global.orientation = .horizontal
        let over = MonocleOverride()  // nothing set
        let resolved = over.resolved(onto: global)
        #expect(resolved.orientation == .horizontal)  // inherited
    }

    @Test("Sparse encode: only set fields, round-trips")
    func sparseRoundTrip() throws {
        var over = MonocleOverride()
        over.orientation = .vertical
        let data = try JSONEncoder().encode(over)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("orientation"))
        let back = try JSONDecoder().decode(
            MonocleOverride.self,
            from: data
        )
        #expect(back == over)
    }

    @Test("An empty override is sparse and inert")
    func emptyIsInert() throws {
        let over = MonocleOverride()
        #expect(over.isEmpty)
        let data = try JSONEncoder().encode(over)
        #expect(String(data: data, encoding: .utf8) == "{}")
        #expect(
            over.resolved(onto: MonocleParams()) == MonocleParams()
        )
    }

    @Test("TilingSettings resolves monocle per space")
    func settingsResolver() {
        var settings = TilingSettings()
        settings.monocle.orientation = .horizontal
        var over = MonocleOverride()
        over.orientation = .vertical
        settings.monocle.override[SpaceID("2")] = over
        #expect(
            settings.resolvedMonocle(for: "2").orientation
                == .vertical
        )
        #expect(
            settings.resolvedMonocle(for: "1").orientation
                == .horizontal
        )
    }

    @Test("override map nests under layout.monocle, round-trips")
    func settingsJSONNesting() throws {
        var settings = TilingSettings()
        var over = MonocleOverride()
        over.orientation = .vertical
        settings.monocle.override[SpaceID("3")] = over
        let data = try JSONEncoder().encode(settings)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"override\""))
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(back.monocle.override == settings.monocle.override)
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

@Suite("monocle.set_orientation_override (#17)", .serialized)
@MainActor
struct MonocleOverrideCommandTests {
    @Test("orientation override writes only that space")
    func orientationOverride() {
        let core = makeCore()
        #expect(
            core.execute(
                "monocle.set_orientation_override",
                args: [.string("2"), .string("vertical")]
            ).isSuccess
        )
        let over =
            core.tiler.settings.monocle.override[SpaceID("2")]
        #expect(over?.orientation == .vertical)
        // The global params are untouched.
        #expect(
            core.tiler.settings.monocle.orientation == .horizontal
        )
        #expect(
            core.tiler.settings.resolvedMonocle(for: "2")
                .orientation == .vertical
        )
        #expect(
            core.tiler.settings.resolvedMonocle(for: "1")
                .orientation == .horizontal
        )
    }

    @Test("Invalid value is rejected and writes nothing")
    func invalidRejected() {
        let core = makeCore()
        #expect(
            !core.execute(
                "monocle.set_orientation_override",
                args: [.string("2"), .string("sideways")]
            ).isSuccess
        )
        #expect(core.tiler.settings.monocle.override.isEmpty)
        // Missing value is rejected too.
        #expect(
            !core.execute(
                "monocle.set_orientation_override",
                args: [.string("vertical")]
            ).isSuccess
        )
    }
}
