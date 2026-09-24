import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The `1` `StateCoordinator.init` seeds so state is never
/// spaceless is retired by the first config load unless that load
/// declared it (#1526): renaming every Space away from a number
/// must not bring a `1` back on the next launch.
@Suite("Boot placeholder space (#1526)", .serialized)
@MainActor
struct PlaceholderSpaceTests {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-placeholder-\(UUID())")
    }

    private func liveSpaces(_ core: KiwiCore) -> [String] {
        core.state.workspaces.allSpaces.map(\.id.raw)
    }

    private func writeLua(_ source: String, _ core: KiwiCore) throws {
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try source.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    /// Boots once to seed the sidecar, then renames every seeded
    /// Space to a word — the reporter's setup.
    private static let display = Display(
        id: DisplayID(1),
        name: "A",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )

    @discardableResult
    private func namedSetup(in dir: URL) throws -> [String] {
        let core = makeTestCore(configDirectory: dir)
        core.state.workspaces.upsertDisplay(Self.display)
        core.loadConfig()
        var config = try #require(core.guiConfigStore.load())
        for (index, space) in config.spaces.enumerated() {
            config.renameSpace(from: space, to: SpaceID("W\(index)"))
        }
        try core.guiConfigStore.save(config)
        return config.spaces.map(\.raw)
    }

    @Test("a launch over named Spaces adds no `1`")
    func namedSpacesBootWithoutOne() throws {
        let dir = directory()
        let named = try namedSetup(in: dir)
        let core = makeTestCore(configDirectory: dir)
        core.loadConfig()
        #expect(liveSpaces(core) == named)
        #expect(core.state.workspaces.activeSpace == SpaceID("W0"))
    }

    @Test("a placeholder holding a window is kept")
    func occupiedPlaceholderIsKept() throws {
        let dir = directory()
        try namedSetup(in: dir)
        let core = makeTestCore(configDirectory: dir)
        core.state.workspaces.add(WindowID(7), to: SpaceID(1))
        core.loadConfig()
        #expect(liveSpaces(core).contains("1"))
    }

    @Test("a fallback naming the placeholder keeps it")
    func namedByFallbackIsKept() throws {
        let core = makeTestCore(configDirectory: directory())
        try writeLua(
            """
            KiwiDesk.set_mode("Work", "stack")
            KiwiDesk.set_fallback_space("1")
            """,
            core
        )
        core.loadConfig()
        #expect(liveSpaces(core) == ["1", "Work"])
    }

    @Test("known displays do not make the placeholder declared")
    func knownDisplaysStillRetire() throws {
        let dir = directory()
        try namedSetup(in: dir)
        let core = makeTestCore(configDirectory: dir)
        core.state.workspaces.upsertDisplay(Self.display)
        core.loadConfig()
        #expect(!liveSpaces(core).contains("1"))
        #expect(
            !core.state.workspaces.spaces(on: Self.display.id).isEmpty
        )
    }

    @Test("Reset All Settings rules on its Lua-owned seed too")
    func resetRetiresItsSeed() throws {
        let core = makeTestCore(configDirectory: directory())
        try writeLua("KiwiDesk.set_mode(\"Work\", \"stack\")", core)
        core.loadConfig()
        #expect(liveSpaces(core) == ["Work"])
        core.resetAllSettings(trash: { _ in })
        #expect(liveSpaces(core) == ["Work"])
    }

    @Test("a declared `1` survives the boot")
    func declaredOneSurvives() throws {
        let core = makeTestCore(configDirectory: directory())
        core.loadConfig()
        #expect(liveSpaces(core).contains("1"))
    }

    @Test("a config declaring nothing keeps the placeholder")
    func nothingDeclaredKeepsOne() throws {
        let core = makeTestCore(configDirectory: directory())
        try writeLua("KiwiDesk.set_gap_global(4)", core)
        core.loadConfig()
        #expect(liveSpaces(core) == ["1"])
    }

    @Test("the ruling is once: a reload leaves a later `1` alone")
    func reloadNeverRetires() throws {
        let dir = directory()
        try namedSetup(in: dir)
        let core = makeTestCore(configDirectory: dir)
        core.loadConfig()
        _ = core.execute("create_space", args: [.string("1")])
        core.loadConfig()
        #expect(liveSpaces(core).contains("1"))
    }
}
