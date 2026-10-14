import Foundation
import Testing

@testable import KiwiDeskCore

/// The `look.*` verbs (#1685 ▸ Ruling 6b): a wear is live only and
/// reported as pending in the shared look, a save never
/// overwrites, and a bundled look is never deleted.
@Suite("Look commands", .serialized)
@MainActor
struct LookCommandsTests {
    /// A bundled look other than the one a first run wears.
    private func otherBundled(_ core: KiwiCore) throws -> String {
        try #require(
            core.bundledLooks.map(\.name)
                .first { $0 != LookCatalog.defaultName }
        )
    }

    private func rows(_ response: CommandResponse) -> [[String: JSONValue]] {
        guard case .object(let fields)? = response.data,
            case .array(let looks)? = fields["looks"]
        else { return [] }
        return looks.compactMap {
            guard case .object(let row) = $0 else { return nil }
            return row
        }
    }

    private func files(_ core: KiwiCore) -> [Data?] {
        let dir = core.configDirectory
        return ["gui.json", "looks.json", "profiles/Work.json"].map {
            try? Data(contentsOf: dir.appendingPathComponent($0))
        }
    }

    @Test("a wear changes the live look and writes no file")
    func applyWritesNothing() throws {
        let core = try KeepFixture.core()
        let name = try otherBundled(core)
        let before = files(core)
        let settings = core.tiler.settings
        let response = core.execute("look.apply", args: [.string(name)])
        #expect(response.isSuccess)
        #expect(core.tiler.settings != settings)
        #expect(files(core) == before)
        let worn = rows(core.execute("look.list"))
            .first { $0["name"] == .string(name) }
        #expect(worn?["worn"] == .string("applied"))
        #expect(worn?["bundled"] == .bool(true))
    }

    @Test("a follower's wear is reported pending in the shared look")
    func applyReportsSharedLook() throws {
        let core = try KeepFixture.core()
        let response = KeepFixture.report(
            core,
            "look.apply",
            [.string(try otherBundled(core))]
        )
        let touched = response.changes?.touched ?? []
        #expect(!touched.isEmpty)
        // A follower keeps the look in the shared look; the glass
        // leaves a look also writes stay the profile's.
        let shared = touched.filter { $0.owner == .sharedLook }
        #expect(!shared.isEmpty)
        #expect(shared.allSatisfy { $0.notKeepable == nil })
    }

    @Test("an unknown or missing name is refused")
    func applyRefusesUnknown() throws {
        let core = try KeepFixture.core()
        #expect(
            !core.execute("look.apply", args: [.string("Nope")])
                .isSuccess
        )
        #expect(!core.execute("look.apply").isSuccess)
    }

    @Test("current names a setter for every path and its owner")
    func currentReadsTheLook() throws {
        let core = try KeepFixture.core()
        guard case .object(let fields)? = core.execute("look.current").data,
            case .object(let setters)? = fields["setters"],
            case .object(let style)? = fields["style"]
        else {
            Issue.record("no look")
            return
        }
        #expect(setters.count == (LookKeys.all + ColorPaletteKeys.all).count)
        #expect(setters["border.width"] == .string("border.set_width"))
        #expect(style["border.width"] != nil)
        #expect(fields["follows_shared_look"] == .bool(true))
        #expect(fields["followers"] == .array([.string("Work")]))
    }

    @Test("a saved look wears back to the same settings")
    func saveRoundTrips() throws {
        let core = try KeepFixture.core()
        #expect(
            core.execute(
                "look.apply",
                args: [
                    .string(try otherBundled(core))
                ]
            ).isSuccess
        )
        let settings = core.tiler.settings
        #expect(
            core.execute("look.save", args: [.string(" Mine ")])
                .isSuccess
        )
        #expect(core.lookLibrary.hasUserLook("Mine"))
        #expect(
            core.execute(
                "look.apply",
                args: [
                    .string(LookCatalog.defaultName)
                ]
            ).isSuccess
        )
        #expect(
            core.execute("look.apply", args: [.string("Mine")])
                .isSuccess
        )
        #expect(core.tiler.settings == settings)
        let saved = rows(core.execute("look.list"))
            .first { $0["name"] == .string("Mine") }
        #expect(saved?["bundled"] == .bool(false))
    }

    @Test("a save refuses an empty, bundled or taken name")
    func saveNeverOverwrites() throws {
        let core = try KeepFixture.core()
        #expect(
            !core.execute("look.save", args: [.string("  ")])
                .isSuccess
        )
        #expect(
            !core.execute(
                "look.save",
                args: [
                    .string(LookCatalog.defaultName)
                ]
            ).isSuccess
        )
        #expect(
            core.execute("look.save", args: [.string("Mine")])
                .isSuccess
        )
        let stored = try Data(
            contentsOf: core.lookLibrary.url
        )
        #expect(
            core.execute(
                "look.apply",
                args: [
                    .string(try otherBundled(core))
                ]
            ).isSuccess
        )
        #expect(
            !core.execute("look.save", args: [.string("Mine")])
                .isSuccess
        )
        #expect(try Data(contentsOf: core.lookLibrary.url) == stored)
    }

    @Test("a delete removes a saved look and never a bundled one")
    func deleteSavedOnly() throws {
        let core = try KeepFixture.core()
        #expect(
            core.execute("look.save", args: [.string("Mine")])
                .isSuccess
        )
        #expect(
            core.execute("look.delete", args: [.string("Mine")])
                .isSuccess
        )
        #expect(!core.lookLibrary.hasUserLook("Mine"))
        #expect(
            !core.execute("look.delete", args: [.string("Mine")])
                .isSuccess
        )
        #expect(
            !core.execute(
                "look.delete",
                args: [
                    .string(LookCatalog.defaultName)
                ]
            ).isSuccess
        )
        #expect(APIReference.destructive.contains("look.delete"))
    }

    @Test("a save and a delete tell an open Settings")
    func libraryChangeIsAnnounced() throws {
        let core = try KeepFixture.core()
        var told = 0
        core.onLookLibraryChanged = { told += 1 }
        #expect(core.execute("look.save", args: [.string("Mine")]).isSuccess)
        #expect(core.execute("look.delete", args: [.string("Mine")]).isSuccess)
        #expect(told == 2)
        #expect(
            !core.execute("look.delete", args: [.string("Mine")]).isSuccess
        )
        #expect(told == 2)
    }

    @Test("an unreadable library says so rather than naming no look")
    func unreadableLibraryIsNamed() throws {
        let core = try KeepFixture.core()
        try Data("not json".utf8).write(to: core.lookLibrary.url)
        let apply = core.execute("look.apply", args: [.string("Mine")])
        #expect(apply.error == "the look library cannot be read")
        let delete = core.execute("look.delete", args: [.string("Mine")])
        #expect(delete.error == "the look library cannot be read")
        #expect(
            core.execute(
                "look.apply",
                args: [
                    .string(LookCatalog.defaultName)
                ]
            ).isSuccess
        )
    }
}
