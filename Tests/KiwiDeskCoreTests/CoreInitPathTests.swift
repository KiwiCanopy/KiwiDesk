import Foundation
import Testing

@testable import KiwiDeskCore

/// `KiwiCore.init`'s construction helpers (`KiwiCore+Init`).
///
/// The default config directory had been reachable from no test
/// at all: `MachineTouchTests` requires every `KiwiCore(` in the
/// test trees to go through `makeTestCore`, which always names a
/// scratch directory, so the `nil` branch was unreachable by
/// construction — a guard-prover run changed both the default
/// path AND the socket filename and the full suite stayed green
/// (2026-08-13). Extracting the helpers for the file-size split
/// is what made them assertable, so they are asserted.
///
/// What a silent change here costs: the default is where a real
/// install's `init.lua`, profiles and sidecar live.
///
/// The socket FILENAME stays unpinned and is stated rather than
/// hidden: `SocketServer.path` is private, so the join is not
/// readable from a test, and `CLIMain` builds its own copy of the
/// same path — so a rename on either side is silent on both. The
/// `profiles` subdirectory is pinned only incidentally, by
/// `ProfileListRulesEditTests`.
@MainActor
@Suite("Core init paths")
struct CoreInitPathTests {
    @Test("the default config directory is ~/.config/KiwiDesk")
    func defaultDirectoryIsUnderDotConfig() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(
            KiwiCore.resolveConfigDirectory(nil)
                == home.appendingPathComponent(".config/KiwiDesk")
        )
    }

    @Test("an explicit directory is taken verbatim")
    func explicitDirectoryWins() {
        let named = URL(fileURLWithPath: "/tmp/kiwi-init-probe")
        #expect(KiwiCore.resolveConfigDirectory(named) == named)
    }

    /// The machine-local half never follows the config folder,
    /// which a user may sync to another Mac (#2324).
    @Test("machine files live in Application Support")
    func machineDirectoryIsApplicationSupport() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = home.appendingPathComponent(
            "Library/Application Support/KiwiDesk"
        )
        #expect(MachineLocation.directory == support)
        #expect(
            MachineLocation.socketPath
                == support.appendingPathComponent("KiwiDesk.sock").path
        )
        #expect(
            MachineLocation.lockPath
                == support.appendingPathComponent("KiwiDesk.lock").path
        )
    }

    /// Without the pin a test core would write its snapshots over
    /// the running app's in `~/Library`; a sibling of the config
    /// dir keeps a file landing in the wrong folder visible. The
    /// twins are held identical by `MachineTouchTests`.
    @Test("a test core keeps its machine files beside its config")
    func testCorePinsTheMachineDirectory() {
        let core = makeTestCore()
        #expect(core.machineDirectory != core.configDirectory)
        #expect(core.machineDirectory != MachineLocation.directory)
        #expect(
            core.machineDirectory.deletingLastPathComponent()
                == core.configDirectory.deletingLastPathComponent()
        )
    }

    /// The slice's claim end to end: what the core itself writes
    /// lands in the machine folder, and the config folder, which
    /// a user may sync, holds none of it.
    @Test("a core writes its socket, snapshots and backups apart")
    func coreWritesMachineFilesApart() {
        let core = makeTestCore()
        defer {
            try? FileManager.default.removeItem(at: core.configDirectory)
            try? FileManager.default.removeItem(at: core.machineDirectory)
        }
        core.onLog = { _ in }
        core.crash.onLog = { _ in }
        core.crash.captureState = { [weak core] in
            core?.state.snapshot()
        }
        core.crash.autosave()
        core.crash.shutdownCleanly()
        core.crash.autosave()
        let machine = core.machineDirectory
        #expect(
            core.socket.path == MachineLocation.socket(in: machine).path
        )
        #expect(
            core.migrationBackups
                == machine.appendingPathComponent("migration-backups")
        )
        let files = FileManager.default
        for name in [CrashRecovery.autosaveName, CrashRecovery.sessionName] {
            #expect(
                files.fileExists(
                    atPath: machine.appendingPathComponent(name).path
                )
            )
            #expect(
                !files.fileExists(
                    atPath: core.configDirectory
                        .appendingPathComponent(name).path
                )
            )
        }
    }

    @Test("the machine directory is created and holds the backups")
    func machineDirectoryHoldsBackups() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-init-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent("config")
        let machine = root.appendingPathComponent("machine")
        let resolved = KiwiCore.resolveDirectories(config, machine)
        #expect(resolved.config == config)
        #expect(resolved.machine == machine)
        #expect(FileManager.default.fileExists(atPath: machine.path))
        let manager = KiwiCore.makeProfileManager(config, machine)
        #expect(
            manager.migrationBackups
                == machine.appendingPathComponent("migration-backups")
        )
    }

    /// A long home must not leave IPC dead: `SocketServer.isLive`
    /// reads a path past `sun_path` as live and refuses to start.
    @Test("a socket path past sun_path falls back to a short one")
    func longSocketPathFallsBack() {
        let short = URL(fileURLWithPath: "/Users/kiwi/Library/KiwiDesk")
        #expect(
            MachineLocation.socket(in: short).path
                == short.appendingPathComponent("KiwiDesk.sock").path
        )
        let long = URL(
            fileURLWithPath: "/Users/" + String(repeating: "k", count: 90)
        )
        let socket = MachineLocation.socket(in: long).path
        #expect(socket.utf8.count < MachineLocation.socketPathLimit)
        #expect(!socket.hasPrefix(long.path))
        #expect(socket == MachineLocation.socket(in: long).path)
        let other = long.appendingPathComponent("other")
        #expect(socket != MachineLocation.socket(in: other).path)
    }
}
