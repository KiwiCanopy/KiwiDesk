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

    /// Boots once to seed the sidecar, then renames every seeded
    /// Space to a word — the reporter's setup.
    private func namedSetup(in dir: URL) throws {
        let core = makeTestCore(configDirectory: dir)
        core.loadConfig()
        var config = try #require(core.guiConfigStore.load())
        for (index, space) in config.spaces.enumerated() {
            config.renameSpace(from: space, to: SpaceID("W\(index)"))
        }
        try core.guiConfigStore.save(config)
    }

    @Test("a launch over named Spaces adds no `1`")
    func namedSpacesBootWithoutOne() throws {
        let dir = directory()
        try namedSetup(in: dir)
        let core = makeTestCore(configDirectory: dir)
        core.loadConfig()
        #expect(liveSpaces(core) == ["W0", "W1", "W2"])
        #expect(core.state.workspaces.activeSpace == SpaceID("W0"))
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
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "KiwiDesk.set_gaps(4)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
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
