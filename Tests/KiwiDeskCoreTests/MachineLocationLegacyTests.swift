import Foundation
import Testing

@testable import KiwiDeskCore

/// The one-time hand-over of this Mac's files from the config
/// folder to the machine folder (#2324): an update keeps the
/// arrangement it quit with, and the synced folder is left with
/// the setup alone.
struct MachineLocationLegacyTests {
    /// Under `/tmp`, short: a socket path past `sun_path`'s 104
    /// bytes reads as live (`SocketServer.isLive`) and is kept.
    private static func folders() -> (URL, URL, URL) {
        let root = URL(fileURLWithPath: "/tmp")
            .appendingPathComponent("kd-\(UUID().uuidString.prefix(8))")
        let config = root.appendingPathComponent("config")
        let machine = root.appendingPathComponent("machine")
        for dir in [config, machine] {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
        return (root, config, machine)
    }

    private static func write(_ text: String, _ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }

    private static func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map {
            String(decoding: $0, as: UTF8.self)
        }
    }

    @Test("snapshots and backups move to the machine folder")
    func legacyFilesMove() throws {
        let (root, config, machine) = Self.folders()
        defer { try? FileManager.default.removeItem(at: root) }
        let backup = "migration-backups/gui.json.pre-v7"
        for name in [".state_snapshot", ".session_snapshot", backup] {
            try Self.write(name, config.appendingPathComponent(name))
        }
        MachineLocation.adoptLegacyFiles(from: config, into: machine)
        for name in [".state_snapshot", ".session_snapshot", backup] {
            #expect(Self.read(machine.appendingPathComponent(name)) == name)
            #expect(
                !FileManager.default.fileExists(
                    atPath: config.appendingPathComponent(name).path
                )
            )
        }
    }

    @Test("a file the machine folder holds is never overwritten")
    func machineFileWins() throws {
        let (root, config, machine) = Self.folders()
        defer { try? FileManager.default.removeItem(at: root) }
        let name = ".session_snapshot"
        try Self.write("old", config.appendingPathComponent(name))
        try Self.write("new", machine.appendingPathComponent(name))
        MachineLocation.adoptLegacyFiles(from: config, into: machine)
        #expect(Self.read(machine.appendingPathComponent(name)) == "new")
        #expect(Self.read(config.appendingPathComponent(name)) == "old")
    }

    @Test("one folder for both moves and removes nothing")
    func sameFolderIsANoOp() throws {
        let (root, config, _) = Self.folders()
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = config.appendingPathComponent(".state_snapshot")
        let socket = config.appendingPathComponent("KiwiDesk.sock")
        try Self.write("kept", snapshot)
        try Self.write("", socket)
        MachineLocation.adoptLegacyFiles(from: config, into: config)
        #expect(Self.read(snapshot) == "kept")
        #expect(FileManager.default.fileExists(atPath: socket.path))
    }

    @Test("a stale socket left in the config folder is removed")
    func staleSocketIsRemoved() throws {
        let (root, config, machine) = Self.folders()
        defer { try? FileManager.default.removeItem(at: root) }
        let socket = config.appendingPathComponent("KiwiDesk.sock")
        try Self.write("", socket)
        MachineLocation.adoptLegacyFiles(from: config, into: machine)
        #expect(!FileManager.default.fileExists(atPath: socket.path))
    }
}
