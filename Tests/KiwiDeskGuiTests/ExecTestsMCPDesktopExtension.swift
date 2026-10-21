import Foundation
import Testing

@testable import KiwiDesk

/// The extension really staged, packed with `ditto` and unpacked,
/// and its launcher really run (#2258). Spawns `ditto` and the
/// launcher, so it lives in the ExecTests partition
/// (`MachineTouchTests`).
@Suite("ExecTests: MCP Claude Desktop extension")
struct ExecTestsMCPDesktopExtension {
    static func run(_ tool: String, _ arguments: [String]) throws
        -> (status: Int32, error: String)
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let error = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = error
        try process.run()
        let data = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: data, as: UTF8.self)
        )
    }

    /// The archive's entries as `zipinfo` lists them — what Claude
    /// Desktop's unzip sees, `._` side files included.
    static func entries(of archive: URL) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        process.arguments = ["-1", archive.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n").map(String.init).sorted()
    }

    static func scratch() -> URL {
        testTemporaryDirectory
            .appendingPathComponent("kiwi-mcpb-\(UUID().uuidString)")
    }

    @Test("a packed bundle unpacks to an executable launcher at its root")
    func packRoundTrip() throws {
        let files = FileManager.default
        let folder = Self.scratch()
        defer { try? files.removeItem(at: folder) }
        let staged = folder.appendingPathComponent("bundle")
        let packed = folder.appendingPathComponent("KiwiDesk.mcpb")
        let unpacked = folder.appendingPathComponent("unpacked")
        try MCPDesktopExtension.stage(
            in: staged,
            executable: "/usr/bin/true",
            version: "1.2.3",
            icon: Data([0x89, 0x50])
        )
        // Every staged file carries an attribute, as files a process
        // writes often do, so the archive must leave its `._` side
        // file out on any host, not only one that stamps them.
        for name in [
            "manifest.json", MCPDesktopExtension.launcherPath,
            MCPDesktopExtension.iconPath,
        ] {
            let path = staged.appendingPathComponent(name).path
            let value = Array("kiwi".utf8)
            #expect(
                setxattr(path, "com.kiwidesk.test", value, value.count, 0, 0)
                    == 0
            )
        }
        try MCPDesktopExtension.pack(staged, to: packed)
        // Exactly the bundle's files: no `._` metadata entries.
        #expect(
            try Self.entries(of: packed) == [
                MCPDesktopExtension.iconPath, "manifest.json", "server/",
                MCPDesktopExtension.launcherPath,
            ]
        )
        let unzip = try Self.run(
            "/usr/bin/ditto",
            ["-x", "-k", packed.path, unpacked.path]
        )
        #expect(unzip.status == 0)
        for name in [
            "manifest.json", MCPDesktopExtension.launcherPath,
            MCPDesktopExtension.iconPath,
        ] {
            let path = unpacked.appendingPathComponent(name).path
            #expect(files.fileExists(atPath: path), "missing \(name)")
        }
        let launcher =
            unpacked
            .appendingPathComponent(MCPDesktopExtension.launcherPath)
            .path
        #expect(files.isExecutableFile(atPath: launcher))
        #expect(try Self.run(launcher, []).status == 0)
    }

    @Test("a launcher whose app is gone says where it looked")
    func missingApp() throws {
        let files = FileManager.default
        let folder = Self.scratch()
        defer { try? files.removeItem(at: folder) }
        try MCPDesktopExtension.stage(
            in: folder,
            executable: "/nonexistent/KiwiDesk",
            version: "1.2.3",
            icon: nil
        )
        let launcher =
            folder
            .appendingPathComponent(MCPDesktopExtension.launcherPath)
            .path
        let run = try Self.run(launcher, [])
        #expect(run.status == 1)
        #expect(run.error.contains("/nonexistent/KiwiDesk"))
    }
}
