import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Claude Desktop extension the AI page builds on click
/// (#2258 ▸ Ruling): its manifest names the server `kiwidesk mcp`
/// reports, its launcher starts the running copy with the server's
/// arguments, and it carries the app's version.
@Suite("MCP Claude Desktop extension")
struct MCPDesktopExtensionTests {
    static func manifest() throws -> [String: Any] {
        let data = try MCPDesktopExtension.manifest(version: "9.8.7")
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    @Test("the manifest names the server and starts its launcher")
    func manifestShape() throws {
        let manifest = try Self.manifest()
        #expect(manifest["manifest_version"] as? String == "0.3")
        #expect(manifest["name"] as? String == MCPInvocation.serverName)
        #expect(manifest["version"] as? String == "9.8.7")
        #expect(
            manifest["icon"] as? String == MCPDesktopExtension.iconPath
        )
        let server = try #require(manifest["server"] as? [String: Any])
        #expect(server["type"] as? String == "binary")
        let entry = MCPDesktopExtension.launcherPath
        #expect(server["entry_point"] as? String == entry)
        let config = try #require(
            server["mcp_config"] as? [String: Any]
        )
        #expect(config["command"] as? String == "${__dirname}/\(entry)")
        let compatibility = try #require(
            manifest["compatibility"] as? [String: Any]
        )
        #expect(compatibility["platforms"] as? [String] == ["darwin"])
    }

    @Test("the manifest carries every field the bundle format requires")
    func requiredFields() throws {
        let manifest = try Self.manifest()
        for key in [
            "manifest_version", "name", "version", "description",
            "author", "server",
        ] {
            #expect(manifest[key] != nil, "missing \(key)")
        }
        let author = try #require(manifest["author"] as? [String: Any])
        #expect(author["name"] is String)
    }

    /// Every installed extension carries this link, so the heading
    /// it lands on cannot be renamed silently.
    @Test("the documentation link lands on a cli.md heading")
    func documentationAnchor() throws {
        let manifest = try Self.manifest()
        let link = try #require(manifest["documentation"] as? String)
        let anchor = try #require(link.split(separator: "#").last)
        let cli = try String(
            contentsOf: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("docs/cli.md"),
            encoding: .utf8
        )
        let slugs = cli.split(separator: "\n")
            .filter { $0.hasPrefix("## ") }
            .map {
                $0.dropFirst(3).lowercased()
                    .replacingOccurrences(of: " ", with: "-")
            }
        #expect(slugs.contains(String(anchor)), "\(anchor)")
    }

    @Test("the launcher starts the given copy with the server's arguments")
    func launcher() {
        let script = MCPDesktopExtension.launcher(
            executable: "/Users/me/Apps/Kiwi Desk's.app/KiwiDesk"
        )
        #expect(script.hasPrefix("#!/bin/sh\n"))
        let quoted = #"KIWIDESK='/Users/me/Apps/Kiwi Desk'\''s.app/KiwiDesk'"#
        #expect(script.contains(quoted))
        let args = MCPInvocation.args.map(MCPDesktopExtension.shellQuoted)
        #expect(
            script.contains(
                #"exec "$KIWIDESK" "# + args.joined(separator: " ")
            )
        )
    }
}
