import Foundation
import Testing

@testable import KiwiDeskCore

/// `export_setup` and `restore_setup` (#2517) through the real
/// dispatch: the flags, the path rule and the replies a CLI user
/// reads.
@Suite("Backup verbs (#2517)")
@MainActor
struct BackupCommandTests {
    private func core() throws -> KiwiCore {
        let core = makeTestCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try core.guiConfigStore.save(GuiConfig())
        try "print('mine')\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        return core
    }

    private func file(_ core: KiwiCore) -> URL {
        core.configDirectory
            .appendingPathComponent("backup-\(UUID().uuidString).json")
    }

    private func field(
        _ response: CommandResponse,
        _ key: String
    ) -> JSONValue? {
        guard case .object(let object)? = response.data else {
            return nil
        }
        return object[key]
    }

    @Test("export writes the file, init.lua only with the flag")
    func exportFlag() throws {
        let core = try core()
        let plain = file(core)
        let reply = core.execute(
            KiwiCore.exportSetupCommand,
            args: [.string(plain.path)]
        )
        #expect(reply.isSuccess)
        #expect(field(reply, "init_lua") == .string("not_asked"))
        #expect(try core.readBackup(at: plain).initLua == nil)

        let carried = file(core)
        let flagged = core.execute(
            KiwiCore.exportSetupCommand,
            args: [
                .string(KiwiCore.includeInitLuaFlag),
                .string(carried.path),
            ]
        )
        #expect(flagged.isSuccess)
        #expect(field(flagged, "init_lua") == .string("included"))
        #expect(
            try core.readBackup(at: carried).initLua == "print('mine')\n"
        )
    }

    @Test("a relative path, a second path or no path is refused")
    func pathRule() throws {
        let core = try core()
        for args: [JSONValue] in [
            [.string("backup.json")],
            [.string("/a.json"), .string("/b.json")],
            [],
        ] {
            #expect(
                !core.execute(KiwiCore.exportSetupCommand, args: args)
                    .isSuccess
            )
            #expect(
                !core.execute(KiwiCore.restoreSetupCommand, args: args)
                    .isSuccess
            )
        }
    }

    @Test("restore takes init.lua only with the flag, and says so")
    func restoreFlag() throws {
        let source = try core()
        let url = file(source)
        try "print('theirs')\n".write(
            to: source.configURL,
            atomically: true,
            encoding: .utf8
        )
        try source.writeBackup(to: url, includingInitLua: true)

        let target = try core()
        var reloads = 0
        target.onSetupRestored = { reloads += 1 }
        let plain = target.execute(
            KiwiCore.restoreSetupCommand,
            args: [.string(url.path)]
        )
        #expect(plain.isSuccess)
        #expect(field(plain, "init_lua") == .string("left_alone"))
        #expect(
            try String(contentsOf: target.configURL, encoding: .utf8)
                == "print('mine')\n"
        )
        let flagged = target.execute(
            KiwiCore.restoreSetupCommand,
            args: [.string(url.path), .string(KiwiCore.initLuaFlag)]
        )
        #expect(flagged.isSuccess)
        #expect(field(flagged, "init_lua") == .string("replaced"))
        #expect(
            try String(contentsOf: target.configURL, encoding: .utf8)
                == "print('theirs')\n"
        )
        #expect(reloads == 2)
    }

    @Test("a refused restore leaves an open Settings draft alone")
    func refusalReloadsNothing() throws {
        let core = try core()
        var reloads = 0
        core.onSetupRestored = { reloads += 1 }
        let reply = core.execute(
            KiwiCore.restoreSetupCommand,
            args: [.string(file(core).path)]
        )
        #expect(!reply.isSuccess)
        #expect(reloads == 0)
    }
}
