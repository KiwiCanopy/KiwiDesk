import Foundation
import Testing

@testable import KiwiDeskCore

/// Which Space each Desktop was showing survives a restart
/// (#1230). Without it every Desktop is a first visit again after
/// a quit, and the assignment permutes — the confusion this issue
/// opens with, triggered by quitting rather than by swiping.
///
/// The key rule is the one this suite exists for: **identity
/// entries persist, number entries do not.** A `.number` is the
/// bridge-absent fallback and means nothing without saying whose
/// numbering it is, so two arrangements collide on one entry.
/// `virtualSpaces` accepts that in memory because a wrong answer
/// heals at the next departure; persisted it never does
/// (profiles.md).
@Suite("Per-Desktop Space persistence (#1230)", .serialized)
struct DesktopSpacePersistenceTests {
    private let stamp = DesktopIdentity(raw: "STAMP-P")

    private func roundTrip(_ config: GuiConfig) throws -> GuiConfig {
        let data = try JSONEncoder().encode(config)
        return try JSONDecoder().decode(GuiConfig.self, from: data)
    }

    @Test("An identity-keyed Space survives the round trip")
    func identityPersists() throws {
        var config = GuiConfig()
        config.desktopSpaces = [.identity(stamp): SpaceID(3)]
        #expect(
            try roundTrip(config).desktopSpaces[.identity(stamp)]
                == SpaceID(3)
        )
    }

    /// The number fallback is dropped at the WRITE, so a renumber
    /// cannot re-point a persisted entry at another Desktop.
    @Test("A number-keyed Space is not written")
    func numberIsDropped() throws {
        var config = GuiConfig()
        config.desktopSpaces = [
            .identity(stamp): SpaceID(3),
            .number(2): SpaceID(4),
        ]
        let back = try roundTrip(config)
        #expect(back.desktopSpaces[.number(2)] == nil)
        #expect(
            back.desktopSpaces[.identity(stamp)] == SpaceID(3)
        )
    }

    /// Additive: a file written before #1230 has no such key, and
    /// decodes to "no Desktop remembers a Space yet" — which is
    /// why this needed no format bump and no migration.
    @Test("A file without the key decodes to empty")
    func absentKeyDecodesEmpty() throws {
        let json = """
            {"format":2,"spaces":["1"],"app_rules":{},
             "float_rules":[],"ignore_rules":[],
             "profile_bindings":{},"layers":[]}
            """
        let config = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(json.utf8)
        )
        #expect(config.desktopSpaces.isEmpty)
    }

    /// The stored spelling is the Desktop's own, so a hand-read
    /// file names the stamp rather than an index.
    @Test("The stored key is the stamp itself")
    func storedKeyIsTheStamp() throws {
        var config = GuiConfig()
        config.desktopSpaces = [.identity(stamp): SpaceID(1)]
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("STAMP-P"))
        #expect(text.contains("desktop_spaces"))
    }
}

/// The two wiring sites, which the round trip above cannot see:
/// a decoded config has to reach `virtualSpaces`, and the live
/// map has to reach the seeded config.
@Suite("Per-Desktop Space persistence wiring (#1230)", .serialized)
@MainActor
struct DesktopSpacePersistenceWiringTests {
    private let stamp = DesktopIdentity(raw: "STAMP-W")

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-persist-\(UUID().uuidString)"
                )
        )
    }

    @Test("A saved config seeds the live memory on load")
    func loadSeedsTheMemory() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.desktopSpaces = [.identity(stamp): SpaceID(2)]
        try core.guiConfigStore.save(config)
        core.applyStructuredConfig()
        #expect(
            core.desktopMemory.virtualSpaces[.identity(stamp)]
                == SpaceID(2)
        )
    }

    /// A reload mid-session must not discard what THIS session
    /// learned about a Desktop the file cannot name — the
    /// `.number` entries, which the encoder never writes.
    @Test("A reload keeps this session's number entries")
    func reloadKeepsNumberEntries() throws {
        let core = makeCore()
        core.rememberVirtualSpace(SpaceID(3), leaving: .number(4))
        var config = GuiConfig()
        config.desktopSpaces = [.identity(stamp): SpaceID(2)]
        try core.guiConfigStore.save(config)
        core.applyStructuredConfig()
        #expect(
            core.desktopMemory.virtualSpaces[.number(4)]
                == SpaceID(3)
        )
    }

    /// The hazard the write-time stamp closes. Most writers hand
    /// back a config they loaded EARLIER and edited — a Settings
    /// save is the everyday one — so without stamping, that
    /// copy's stale map would overwrite what the session learned
    /// since, and the persistence would be silently lossy in its
    /// most common flow.
    @Test("A save stamps the live memory over a stale copy")
    func saveStampsOverAStaleCopy() throws {
        let core = makeCore()
        // A config held from before the Desktop was ever shown.
        var stale = GuiConfig()
        stale.desktopSpaces = [:]
        core.rememberVirtualSpace(
            SpaceID(7),
            leaving: .identity(stamp)
        )
        try core.guiConfigStore.save(stale)
        #expect(
            core.guiConfigStore.load()?
                .desktopSpaces[.identity(stamp)] == SpaceID(7)
        )
    }

    /// A cleared memory must reach the file. "Empty means do not
    /// stamp" made the map unclearable through its own write
    /// path: a discard left the file's copy standing and the next
    /// boot adopted it back.
    @Test("A cleared memory clears the file")
    func clearedMemoryClearsTheFile() throws {
        let core = makeCore()
        core.rememberVirtualSpace(
            SpaceID(4),
            leaving: .identity(stamp)
        )
        try core.guiConfigStore.save(GuiConfig())
        #expect(
            core.guiConfigStore.load()?.desktopSpaces.isEmpty
                == false
        )
        core.discardSavedArrangement()
        try core.guiConfigStore.save(GuiConfig())
        #expect(
            core.guiConfigStore.load()?.desktopSpaces.isEmpty
                == true
        )
    }

    /// A SAVED seed carries the live memory — asserted on the
    /// file rather than on `guiConfigSeed()`'s return, because
    /// the seed is also the no-sidecar fallback for readers and
    /// only a WRITE stamps the memory in. One mechanism, and the
    /// outcome is what matters.
    @Test("A saved seed carries the live memory")
    func savedSeedCarriesTheMemory() throws {
        let core = makeCore()
        core.rememberVirtualSpace(
            SpaceID(5),
            leaving: .identity(stamp)
        )
        try core.guiConfigStore.save(core.guiConfigSeed())
        #expect(
            core.guiConfigStore.load()?
                .desktopSpaces[.identity(stamp)] == SpaceID(5)
        )
    }

    /// The write TRIGGER. Nothing else writes `gui.json` at a
    /// moment that matters — the eight writers are user actions —
    /// so without this the memory reached disk only if the user
    /// happened to save something after their last swipe, and
    /// "survives quitting" was true by luck.
    @Test("Quitting writes the Desktop memory")
    func quitPersistsTheMemory() throws {
        let core = makeCore()
        try core.guiConfigStore.save(GuiConfig())
        core.rememberVirtualSpace(
            SpaceID(6),
            leaving: .identity(stamp)
        )
        core.persistDesktopSpaceMemory()
        #expect(
            core.guiConfigStore.load()?
                .desktopSpaces[.identity(stamp)] == SpaceID(6)
        )
    }

    /// A Lua-owned setup has no sidecar to write, so the memory
    /// stays session-only there — config ownership, not a gap.
    @Test("A Lua-owned config is not written")
    func luaOwnedConfigIsNotWritten() {
        let core = makeCore()
        core.rememberVirtualSpace(
            SpaceID(6),
            leaving: .identity(stamp)
        )
        // No sidecar on disk: `isGuiManaged` is false and the
        // load finds nothing, so this must not create one.
        core.persistDesktopSpaceMemory()
        #expect(core.guiConfigStore.load() == nil)
    }
}
