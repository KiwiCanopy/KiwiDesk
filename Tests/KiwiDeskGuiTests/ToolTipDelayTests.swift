import Foundation
import Testing

@testable import KiwiDesk

/// Hover help is useless if it arrives after the pointer has
/// left, so the shortened `NSInitialToolTipDelay` is load-bearing
/// for every `GreyOut(help:)` sentence in Settings. Two halves,
/// because each fails on its own: the value and its *fallback*
/// semantics, and the fact that launch actually installs it.
@Suite("Tooltip delay")
struct ToolTipDelayTests {
    private func scratchDefaults(_ name: String) -> UserDefaults {
        let suite = "kiwidesk.tests.tooltip.\(name)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    /// Both sides of an `install`-then-read assertion derive from
    /// the same two symbols, so on its own it pins neither. The
    /// key is an **AppKit** contract — restating the literal is
    /// the derivation, the authority being AppKit and not a
    /// second copy in this repo — and a typo there ships a
    /// permanently ~2s delay with everything else green.
    @Test("the key is the one AppKit reads")
    func keyMatchesAppKit() {
        #expect(ToolTipDelay.key == "NSInitialToolTipDelay")
    }

    /// The band `ToolTipDelay` itself argues for: fast enough that
    /// a reader who pauses is not left concluding there is nothing
    /// to read, slow enough that a pointer merely crossing a row
    /// doesn't fire it. Prose nothing guards is prose that drifts.
    @Test("the delay stays in its defended band")
    func delayInBand() {
        #expect((500...1000).contains(ToolTipDelay.milliseconds))
    }

    @Test("installs the shortened delay")
    func installsDelay() {
        let defaults = scratchDefaults("install")
        defer {
            UserDefaults().removePersistentDomain(
                forName: "kiwidesk.tests.tooltip.install"
            )
        }
        #expect(defaults.object(forKey: ToolTipDelay.key) == nil)
        ToolTipDelay.install(into: defaults)
        #expect(
            defaults.integer(forKey: ToolTipDelay.key)
                == ToolTipDelay.milliseconds
        )
    }

    /// Registering only supplies a fallback, so a user who has
    /// picked their own delay keeps it. `set` here would silently
    /// overwrite a system-wide preference.
    @Test("a user's own delay wins")
    func userValueWins() {
        let defaults = scratchDefaults("user")
        defer {
            UserDefaults().removePersistentDomain(
                forName: "kiwidesk.tests.tooltip.user"
            )
        }
        defaults.set(1234, forKey: ToolTipDelay.key)
        ToolTipDelay.install(into: defaults)
        #expect(defaults.integer(forKey: ToolTipDelay.key) == 1234)
    }

    /// The value is inert unless launch installs it, and nothing
    /// about `ToolTipDelay` compiling proves that it does.
    ///
    /// Scoped to the launch method's **body**, not the file: a
    /// count over the whole file is satisfied by the call sitting
    /// in `applicationWillTerminate` (proven), where it would run
    /// after every window has already closed.
    @Test("launch installs it")
    func launchInstallsIt() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let delegate = root.appendingPathComponent(
            "Sources/KiwiDesk/AppDelegate.swift"
        )
        let source = try String(contentsOf: delegate, encoding: .utf8)
        let head = "func applicationDidFinishLaunching"
        let range = try #require(
            source.range(of: head),
            "launch method not found — repoint this guard"
        )
        let characters = Array(source)
        var cursor = source.distance(
            from: source.startIndex,
            to: range.upperBound
        )
        // Step over the parameter list, then take the body.
        _ = SourceScan.balanced(
            characters,
            from: &cursor,
            open: "(",
            close: ")"
        )
        let body = try #require(
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "could not read the launch method's body"
        )
        // A guard over source that read nothing would pass for
        // having found no violations (.claude/rules/tests.md).
        #expect(!body.isEmpty)
        #expect(body.occurrences(of: "ToolTipDelay.install(") == 1)
    }
}
