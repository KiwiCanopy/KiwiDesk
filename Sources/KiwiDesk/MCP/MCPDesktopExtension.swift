import Foundation
import KiwiDeskCore

/// The Claude Desktop extension (`.mcpb`) the AI page builds on
/// click (#2258 ▸ Ruling): a manifest and a launcher that starts
/// THIS copy of KiwiDesk with `mcp`, its path baked in, so the
/// extension matches the running app's version and location. It
/// is unsigned by ruling — it only starts the notarized app.
enum MCPDesktopExtension {
    /// The bundle's file name, and the launcher's path inside it.
    static let fileName = "KiwiDesk.mcpb"
    static let launcherPath = "server/kiwidesk-mcp"
    static let iconPath = "icon.png"
    static let manifestVersion = "0.3"

    /// The manifest, for the app version `version`.
    static func manifest(version: String) throws -> Data {
        let manifest = Manifest(
            manifestVersion: manifestVersion,
            name: MCPInvocation.serverName,
            displayName: "KiwiDesk",
            version: version,
            description:
                "Set up and control the KiwiDesk tiling window "
                + "manager by asking Claude.",
            author: .init(
                name: "Maikel Hajiabadi",
                url: "https://kiwidesk.kiwicanopy.com"
            ),
            homepage: "https://kiwidesk.kiwicanopy.com",
            documentation:
                "https://kiwidesk.kiwicanopy.com/docs/cli/"
                + "#using-kiwidesk-from-ai-apps",
            support: "https://github.com/KiwiCanopy/KiwiDesk/issues",
            icon: iconPath,
            license: "BUSL-1.1",
            server: .init(
                type: "binary",
                entryPoint: launcherPath,
                mcpConfig: .init(
                    command: "${__dirname}/\(launcherPath)",
                    args: []
                )
            ),
            toolsGenerated: true,
            compatibility: .init(platforms: ["darwin"])
        )
        let encoder = JSONEncoder()
        // The format's keys are snake_case (`manifest_version`).
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        do {
            return try encoder.encode(manifest)
        } catch {
            throw Failure.manifestUnencodable
        }
    }

    /// The launcher: starts `executable` with the server's
    /// arguments, or says plainly where KiwiDesk was expected.
    static func launcher(executable: String) -> String {
        let quoted = shellQuoted(executable)
        let args = MCPInvocation.args.map(shellQuoted)
            .joined(separator: " ")
        return """
            #!/bin/sh
            # Starts KiwiDesk's MCP server. Written by KiwiDesk ▸
            # Settings ▸ AI ▸ Add to Claude Desktop.
            KIWIDESK=\(quoted)
            if [ ! -x "$KIWIDESK" ]; then
              echo "KiwiDesk is not at $KIWIDESK. Open KiwiDesk," \
                "then Settings > AI > Add to Claude Desktop again." >&2
              exit 1
            fi
            exec "$KIWIDESK" \(args)

            """
    }

    /// `text` as one single-quoted shell word.
    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private struct Manifest: Encodable {
        struct Author: Encodable {
            let name: String
            let url: String
        }
        struct Server: Encodable {
            struct Config: Encodable {
                let command: String
                let args: [String]
            }
            let type: String
            let entryPoint: String
            let mcpConfig: Config
        }
        struct Compatibility: Encodable {
            let platforms: [String]
        }

        let manifestVersion: String
        let name: String
        let displayName: String
        let version: String
        let description: String
        let author: Author
        let homepage: String
        let documentation: String
        let support: String
        let icon: String
        let license: String
        let server: Server
        let toolsGenerated: Bool
        let compatibility: Compatibility
    }
}
