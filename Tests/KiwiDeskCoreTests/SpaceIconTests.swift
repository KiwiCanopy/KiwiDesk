import Foundation
import Testing

@testable import KiwiDeskCore

// Per-space icons (#68): the `set_space_icon` command, the
// sparse `space.icon` map's round-trip, and rename migration.

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-icon-\(UUID().uuidString)"
            )
    )
}

@Suite("Space icons (#68)")
struct SpaceIconTests {
    @Test("set_space_icon sets and clears")
    @MainActor
    func commandSemantics() {
        let core = makeCore()
        let set = core.execute(
            "set_space_icon",
            args: [.string("mail"), .string("envelope")]
        )
        #expect(set.isSuccess)
        #expect(
            core.tiler.settings.spaceIcons[SpaceID("mail")]
                == "envelope"
        )
        let cleared = core.execute(
            "set_space_icon",
            args: [.string("mail"), .string("")]
        )
        #expect(cleared.isSuccess)
        #expect(
            core.tiler.settings.spaceIcons[SpaceID("mail")]
                == nil
        )
        let missing = core.execute(
            "set_space_icon",
            args: [.string("mail")]
        )
        #expect(!missing.isSuccess)
    }

    @Test("spaceIcons survive an encode/decode round-trip")
    func roundTrip() throws {
        var settings = TilingSettings()
        settings.spaceIcons[SpaceID("web")] = "globe"
        settings.spaceIcons[SpaceID("chat")] = "💬"
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.spaceIcons == settings.spaceIcons)
    }

    @Test("absent space group decodes to no icons")
    func legacyDecode() throws {
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data("{}".utf8)
        )
        #expect(decoded.spaceIcons.isEmpty)
    }

    @Test("rename migrates the space's icon")
    func renameMigratesIcon() {
        var config = GuiConfig()
        config.spaces = [SpaceID("a"), SpaceID("b")]
        config.settings.spaceIcons[SpaceID("a")] = "globe"
        let ok = config.renameSpace(
            from: SpaceID("a"),
            to: SpaceID("web")
        )
        #expect(ok)
        #expect(
            config.settings.spaceIcons[SpaceID("web")]
                == "globe"
        )
        #expect(
            config.settings.spaceIcons[SpaceID("a")] == nil
        )
    }
}
