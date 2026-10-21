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
/// The app and the CLI read the socket path from the one
/// `MachineLocation.socket(in:)`. The `profiles` subdirectory is
/// pinned only incidentally, by `ProfileListRulesEditTests`.
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
    /// the running app's in `~/Library`; a folder of its own keeps
    /// a file landing in the wrong one visible, and nesting it
    /// cleans it with the config dir. The twins are held identical
    /// by `MachineTouchTests`.
    @Test("a test core keeps its machine files in a folder of their own")
    func testCorePinsTheMachineDirectory() {
        let core = makeTestCore()
        #expect(core.machineDirectory != core.configDirectory)
        #expect(core.machineDirectory != MachineLocation.directory)
        #expect(
            core.machineDirectory.deletingLastPathComponent().path
                == core.configDirectory.path
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
            core.socket.path
                == machine.appendingPathComponent("KiwiDesk.sock").path
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
        let root =
            testTemporaryDirectory
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

    /// A Mac still on an older build may share the config folder,
    /// so only the first launch takes the legacy files; a later one
    /// would take that Mac's (#2324). The folder already holds the
    /// lock by then — `main.swift` takes it before any core — so a
    /// launch is told apart by the marker, never by the folder.
    @Test("only the first launch adopts, the lock already there")
    func adoptionRunsOnce() throws {
        let root = URL(fileURLWithPath: "/tmp")
            .appendingPathComponent("kd-\(UUID().uuidString.prefix(8))")
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent("config")
        let machine = root.appendingPathComponent("machine")
        let name = CrashRecovery.sessionName
        let legacy = config.appendingPathComponent(name)
        let files = FileManager.default
        for dir in [config, machine] {
            try files.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
        // What `main.swift` leaves before the core starts.
        let lock = SingleInstanceLock(
            path: machine.appendingPathComponent("KiwiDesk.lock").path
        )
        #expect(lock.acquire())
        defer { lock.release() }
        try Data("first".utf8).write(to: legacy)
        _ = KiwiCore.resolveDirectories(config, machine)
        let moved = machine.appendingPathComponent(name)
        #expect(files.fileExists(atPath: moved.path))
        #expect(!files.fileExists(atPath: legacy.path))
        // The boot consumes it; the older Mac writes its own.
        try files.removeItem(at: moved)
        try Data("other Mac".utf8).write(to: legacy)
        _ = KiwiCore.resolveDirectories(config, machine)
        #expect(files.fileExists(atPath: legacy.path))
        #expect(!files.fileExists(atPath: moved.path))
    }
}
