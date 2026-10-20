import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What an AI app is told when a keep cannot write (#2490): a file
/// a newer KiwiDesk wrote is named as the reason, apart from a plain
/// failed write, and both point at `get_config_status`.
@Suite("MCP keep refusal wording (#2490)")
struct MCPKeepNewerFormatTests {
    private func told(_ reason: NotKeepable) -> String {
        MCPWording.unkeepable(
            MCPKeepTests.leaf("/settings/border/width", .profile, reason)
        )
    }

    @Test("a newer build's file is the reason, with what to do")
    func newerFormatIsNamed() {
        let sentence = told(.newerFormat)
        #expect(sentence.contains("a newer KiwiDesk wrote its file"))
        #expect(sentence.contains("update KiwiDesk here"))
        #expect(sentence.contains(KiwiCore.configStatusCommand))
    }

    @Test("a plain failed write points at the Config Issues")
    func notWrittenPointsAtTheStatus() {
        let sentence = told(.notWritten)
        #expect(!sentence.contains("newer KiwiDesk"))
        #expect(!sentence.contains("gui.json"))
        #expect(sentence.contains(KiwiCore.configStatusCommand))
    }
}
