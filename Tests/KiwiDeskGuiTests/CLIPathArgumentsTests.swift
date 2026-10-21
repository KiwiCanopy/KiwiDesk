import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The CLI resolves a backup verb's path against the caller's
/// directory before sending it (#2517): the app's own working
/// directory is not the shell's, and Core refuses a relative one.
@Suite("CLI path arguments (#2517)")
struct CLIPathArgumentsTests {
    @Test("a relative path resolves against the caller's directory")
    func relativeResolves() {
        #expect(
            CLIPathArguments.resolved(
                ["backups/../kd.json", KiwiCore.initLuaFlag],
                command: KiwiCore.restoreSetupCommand,
                directory: "/Users/me"
            ) == ["/Users/me/kd.json", KiwiCore.initLuaFlag]
        )
    }

    @Test("a flag first, an absolute path or a tilde stays a path")
    func flagFirstAndAbsolute() {
        #expect(
            CLIPathArguments.resolved(
                [KiwiCore.includeInitLuaFlag, "/Volumes/Disk/kd.json"],
                command: KiwiCore.exportSetupCommand,
                directory: "/Users/me"
            ) == [KiwiCore.includeInitLuaFlag, "/Volumes/Disk/kd.json"]
        )
        let home = CLIPathArguments.resolved(
            ["~/kd.json"],
            command: KiwiCore.exportSetupCommand,
            directory: "/Users/me"
        )
        #expect(home.first?.hasPrefix("/") == true)
        #expect(home.first?.hasSuffix("/kd.json") == true)
    }

    @Test("another verb's arguments are sent as given")
    func otherVerbsUntouched() {
        #expect(
            CLIPathArguments.resolved(
                ["2"],
                command: "focus_space",
                directory: "/Users/me"
            ) == ["2"]
        )
    }
}
