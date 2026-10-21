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

    /// Through `machine.json`'s coding, where the map lives
    /// since #2324.
    private func roundTrip(_ config: GuiConfig) throws -> GuiConfig {
        let data = try JSONEncoder().encode(MachineConfig(of: config))
        return try JSONDecoder().decode(MachineConfig.self, from: data)
            .applied(to: GuiConfig())
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

    /// A Mac that remembers nothing yet has a file without the
    /// key, and decodes to "no Desktop remembers a Space yet".
    @Test("A file without the key decodes to empty")
    func absentKeyDecodesEmpty() throws {
        let config = try JSONDecoder().decode(
            MachineConfig.self,
            from: Data(#"{"format":1}"#.utf8)
        )
        #expect(config.desktopSpaces.isEmpty)
    }

    /// The stored spelling is the Desktop's own, so a hand-read
    /// file names the stamp rather than an index.
    @Test("The stored key is the stamp itself")
    func storedKeyIsTheStamp() throws {
        var config = GuiConfig()
        config.desktopSpaces = [.identity(stamp): SpaceID(1)]
        let data = try JSONEncoder().encode(MachineConfig(of: config))
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
            configDirectory:
                testTemporaryDirectory
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
        // The boot load adopted the (empty) stored memory.
        core.adoptPersistedDesktopSpaces([:])
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
        // The boot load adopted the (empty) stored memory.
        core.adoptPersistedDesktopSpaces([:])
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
        // The boot load adopted the (empty) stored memory.
        core.adoptPersistedDesktopSpaces([:])
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
        // The boot load adopted the (empty) stored memory.
        core.adoptPersistedDesktopSpaces([:])
        core.rememberVirtualSpace(
            SpaceID(6),
            leaving: .identity(stamp)
        )
        // Bytes the encoder never writes, so a rewrite of the same
        // config cannot pass for no write at all.
        let shared = Data(
            #"{"format":\#(GuiConfig.currentFormat),"spaces":[]}"#.utf8
        )
        try shared.write(to: core.guiConfigStore.url)
        core.persistDesktopSpaceMemory()
        #expect(
            core.guiConfigStore.load()?
                .desktopSpaces[.identity(stamp)] == SpaceID(6)
        )
        // A quit writes this Mac's file alone (#2324): `gui.json`
        // may be another Mac's too.
        #expect(try Data(contentsOf: core.guiConfigStore.url) == shared)
    }

    /// Reset All Settings forgets the memory with the settings it
    /// clears (#2324: it no longer rides `gui.json`).
    @Test("Reset clears the Desktop memory file")
    func resetClearsTheMemory() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.desktopSpaces = [.identity(stamp): SpaceID(4)]
        try core.guiConfigStore.save(config)
        let machine = core.url(of: .machineConfig)
        #expect(FileManager.default.fileExists(atPath: machine.path))
        var trashed: [URL] = []
        core.resetAllSettings(trash: { url in
            trashed.append(url)
            try FileManager.default.removeItem(at: url)
        })
        #expect(trashed.contains(machine))
    }

    /// A `gui.json` this build cannot decode — a newer Mac's —
    /// means `machine.json` was never adopted, so a quit after one
    /// swipe must not replace every other Desktop's entry (#2324).
    @Test("An unadopted memory file survives the quit")
    func unadoptedMemorySurvivesTheQuit() throws {
        let core = makeCore()
        let other = DesktopIdentity(raw: "STAMP-OTHER")
        var config = GuiConfig()
        config.desktopSpaces = [.identity(other): SpaceID(3)]
        try core.guiConfigStore.save(config)
        try Data("not json".utf8).write(to: core.guiConfigStore.url)
        core.rememberVirtualSpace(
            SpaceID(6),
            leaving: .identity(stamp)
        )
        core.persistDesktopSpaceMemory()
        #expect(
            core.guiConfigStore.machine.load()
                .desktopSpaces[.identity(other)] == SpaceID(3)
        )
    }

    /// Every writer stamps through the one adoption-gated read,
    /// so a Settings-style save in a session that never adopted
    /// the file keeps what it holds as well (#2324).
    @Test("An unadopted session's save keeps the stored memory")
    func unadoptedSaveKeepsTheMemory() throws {
        let core = makeCore()
        let other = DesktopIdentity(raw: "STAMP-OTHER")
        var config = GuiConfig()
        config.desktopSpaces = [.identity(other): SpaceID(3)]
        try core.guiConfigStore.save(config)
        core.rememberVirtualSpace(
            SpaceID(6),
            leaving: .identity(stamp)
        )
        let loaded = try #require(core.guiConfigStore.load())
        try core.guiConfigStore.save(loaded)
        #expect(
            core.guiConfigStore.machine.load()
                .desktopSpaces[.identity(other)] == SpaceID(3)
        )
    }

    /// A Lua-owned setup has no sidecar to write, so the memory
    /// stays session-only there — config ownership, not a gap.
    @Test("A Lua-owned config is not written")
    func luaOwnedConfigIsNotWritten() {
        let core = makeCore()
        // An adopted memory — the discard adopts whoever owns the
        // config — so only the ownership gate stands between this
        // quit and a written file.
        core.forgetDesktopSpaceMemory()
        core.rememberVirtualSpace(
            SpaceID(6),
            leaving: .identity(stamp)
        )
        // No sidecar on disk: `isGuiManaged` is false and the
        // load finds nothing, so this must not create one.
        core.persistDesktopSpaceMemory()
        #expect(core.guiConfigStore.load() == nil)
        #expect(
            !FileManager.default.fileExists(
                atPath: core.url(of: .machineConfig).path
            )
        )
    }
}
