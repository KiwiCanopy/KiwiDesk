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
}
