import Foundation
import Testing

@testable import KiwiDeskCore

/// A lens is a setting, not a binding (#3317 ruling): a fresh
/// desk whose `init.lua` only defines a lens is Lua-owned and
/// never seeded over, as a `set_*` verb's is (#354).
@Suite("First-run seed: lens-only init.lua (#3317)", .serialized)
@MainActor
struct FirstRunLensSeedTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-lens-seed-\(UUID().uuidString)"
                )
        )
    }

    private func load(_ source: String) throws -> KiwiCore {
        let core = makeCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try source.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        return core
    }

    @Test("a lens-only init.lua is not seeded over")
    func lensOnlyIsNotSeeded() throws {
        let core = try load(
            """
            kiwivision.define_lens({
                name = "Writing",
                apps = { "com.apple.Notes" },
            })
            """
        )
        #expect(!core.guiConfigStore.exists)
        #expect(!core.isGuiManaged)
    }

    @Test("a delete_lens-only init.lua is not seeded over")
    func deleteLensOnlyIsNotSeeded() throws {
        let core = try load(
            #"kiwivision.delete_lens("Writing")"# + "\n"
        )
        #expect(!core.guiConfigStore.exists)
        #expect(!core.isGuiManaged)
    }

    /// Adoption owns the lens: `gui.json` stores it as Settings
    /// draws it, and the line is commented out so the next load
    /// does not define it again as a session lens.
    @Test("adopting a lens-only init.lua stores and comments it")
    func adoptionStoresAndComments() throws {
        let core = try load(
            """
            kiwivision.define_lens({
                name = "Writing",
                apps = { "com.apple.Notes" },
                fade_duration = 700,
            })
            """
        )
        try core.adoptConfigIntoGui { _ in }
        let stored = try #require(
            core.guiConfigStore.load()?.appWide?.visionLenses
        )
        #expect(stored.map(\.name) == ["Writing"])
        #expect(stored.first?.overrides.fadeDuration == nil)
        let file = try String(
            contentsOf: core.configURL,
            encoding: .utf8
        )
        let live = file.components(separatedBy: "\n").filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && !t.hasPrefix("--")
        }
        #expect(live.isEmpty, "live lines: \(live)")
        #expect(file.contains("kiwivision.define_lens({"))
        #expect(core.isGuiManaged)
    }

    /// Control: the same desk with the lens commented out is
    /// seeded, so the cases above read the lens line.
    @Test("a commented-out lens still gets the seed")
    func commentedLensSeeds() throws {
        let core = try load(
            #"-- kiwivision.define_lens({ name = "W" })"# + "\n"
        )
        #expect(core.guiConfigStore.exists)
        #expect(core.isGuiManaged)
    }
}
