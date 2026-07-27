import Foundation
import Testing

@testable import KiwiDeskCore

// The explicit fallback-space reference (#68): the
// `set_fallback_space` command, its save/load round-trip, and
// the `fallback_space` JSON key.

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-fallback-\(UUID().uuidString)"
            )
    )
}

@Suite("Fallback space (#68)", .serialized)
@MainActor
struct FallbackSpaceTests {
    @Test("set_fallback_space sets, validates, and clears")
    func commandSemantics() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("mail"))

        let unknown = core.execute(
            "set_fallback_space",
            args: [.string("nope")]
        )
        #expect(!unknown.isSuccess)
        #expect(core.fallbackSpace == nil)

        let ok = core.execute(
            "set_fallback_space",
            args: [.string("mail")]
        )
        #expect(ok.isSuccess)
        #expect(core.fallbackSpace == SpaceID("mail"))

        let cleared = core.execute(
            "set_fallback_space",
            args: [.string("")]
        )
        #expect(cleared.isSuccess)
        #expect(core.fallbackSpace == nil)
    }

    @Test("save_profile captures the live fallback space")
    func saveCapturesFallback() throws {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("a"))
        core.state.workspaces.ensureSpace(SpaceID("b"))
        _ = core.execute(
            "set_fallback_space",
            args: [.string("b")]
        )
        core.execute("save_profile", args: [.string("p")])
        let saved = try core.profiles.read(name: "p")
        #expect(saved.fallbackSpace == SpaceID("b"))
    }

    @Test("load_profile adopts the stored fallback space")
    func loadAdoptsFallback() throws {
        let core = makeCore()
        let stored = Profile(
            name: "p",
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("a"), SpaceID("b")],
            fallbackSpace: SpaceID("b"),
            spaceModes: [
                SpaceID("a"): .bsp,
                SpaceID("b"): .bsp,
            ],
            settings: TilingSettings()
        )
        try core.profiles.save(stored)
        let load = core.execute(
            "load_profile",
            args: [.string("p")]
        )
        #expect(load.isSuccess)
        #expect(core.fallbackSpace == SpaceID("b"))
    }

    @Test("profile JSON uses the fallback_space key")
    func jsonKey() throws {
        let profile = Profile(
            name: "p",
            monitorSets: [MonitorSet(monitors: ["A:1x1"])],
            spaces: [SpaceID("a")],
            fallbackSpace: SpaceID("a"),
            spaceModes: [SpaceID("a"): .bsp],
            settings: TilingSettings()
        )
        let data = try JSONEncoder().encode(profile)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        #expect(
            object?["fallback_space"] as? String == "a"
        )
        let decoded = try JSONDecoder().decode(
            Profile.self,
            from: data
        )
        #expect(decoded.fallbackSpace == SpaceID("a"))
    }

    @Test("absent key decodes to nil (legacy profiles)")
    func legacyDecodesNil() throws {
        let profile = Profile(
            name: "p",
            monitorSets: [MonitorSet(monitors: ["A:1x1"])],
            spaces: [SpaceID("a")],
            spaceModes: [SpaceID("a"): .bsp],
            settings: TilingSettings()
        )
        let data = try JSONEncoder().encode(profile)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        #expect(object?["fallback_space"] == nil)
        let decoded = try JSONDecoder().decode(
            Profile.self,
            from: data
        )
        #expect(decoded.fallbackSpace == nil)
    }
}
