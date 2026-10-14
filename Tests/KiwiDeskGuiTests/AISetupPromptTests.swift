import Foundation
import Testing

@testable import KiwiDesk

/// The setup prompt an AI app receives (#1685 ▸ Ruling 6a): the
/// server entry must decode back to the exact command, whatever
/// the path holds, and the reply line appears only off English.
@Suite("AI setup prompt")
struct AISetupPromptTests {
    private struct Entry: Decodable {
        struct Server: Decodable {
            let command: String
            let args: [String]
        }
        let mcpServers: [String: Server]
    }

    private func decoded(_ path: String) throws -> Entry.Server? {
        let line = MCPInvocation.serverEntry(executable: path)
        let entry = try JSONDecoder().decode(
            Entry.self,
            from: Data(line.utf8)
        )
        return entry.mcpServers["kiwidesk"]
    }

    @Test(
        "the server entry decodes to the exact executable",
        arguments: [
            "/Applications/KiwiDesk.app/Contents/MacOS/KiwiDesk",
            "/Users/a b/Apps/Kiwi \"Desk\".app/Contents/MacOS/KiwiDesk",
            "/tmp/back\\slash/KiwiDesk",
        ]
    )
    func entryRoundTrips(path: String) throws {
        let server = try decoded(path)
        #expect(server?.command == path)
        #expect(server?.args == ["mcp"])
    }

    /// A slash escaped as `\/` is valid JSON but reads as a
    /// broken path to a person checking the entry by eye.
    @Test("the entry keeps slashes readable")
    func slashesStayPlain() {
        let line = MCPInvocation.serverEntry(
            executable: "/Applications/KiwiDesk.app"
        )
        #expect(line.contains("\"/Applications/KiwiDesk.app\""))
    }

    @Test("the prompt carries the entry and the path")
    func promptCarriesTheEntry() {
        let path = "/Applications/KiwiDesk.app/Contents/MacOS/KiwiDesk"
        let text = AISetupPrompt.text(
            executable: path,
            replyLanguage: nil
        )
        let entry = MCPInvocation.serverEntry(executable: path)
        #expect(text.contains(entry))
        #expect(!text.contains("Reply in"))
    }

    @Test("a non-English Settings language asks for a reply in it")
    func replyLine() {
        #expect(AISetupPrompt.replyLanguage(for: nil) == nil)
        #expect(AISetupPrompt.replyLanguage(for: "en") == nil)
        #expect(AISetupPrompt.replyLanguage(for: "de") == "German")
        let text = AISetupPrompt.text(
            executable: "/x",
            replyLanguage: AISetupPrompt.replyLanguage(for: "ja")
        )
        #expect(text.hasSuffix("Reply in Japanese."))
    }
}
