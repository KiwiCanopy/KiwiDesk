import Testing

@testable import KiwiDesk

/// `kiwidesk mcp`'s verb and server name are stored OUTSIDE this
/// repository — in every installed Claude Desktop extension's
/// launcher and in the published Claude Code plugin (#2258;
/// packaging-and-release.md). The spelled values are the contract,
/// so this pins them as values on purpose: a rename that reds here
/// is a crossing owed to every install, never a tidy-up.
@Suite("MCP invocation contract")
struct MCPInvocationContractTests {
    @Test("the stored verb and server name keep their spelling")
    func storedSpelling() {
        #expect(MCPInvocation.verb == "mcp")
        #expect(MCPInvocation.serverName == "kiwidesk")
        #expect(MCPInvocation.args == ["mcp"])
    }
}
