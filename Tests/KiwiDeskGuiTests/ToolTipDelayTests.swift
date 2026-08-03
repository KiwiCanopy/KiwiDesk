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
    @Test("launch installs it")
    func launchInstallsIt() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let delegate = root.appendingPathComponent(
            "Sources/KiwiDesk/AppDelegate.swift"
        )
        let source = try String(contentsOf: delegate, encoding: .utf8)
        // A guard over source that read nothing would pass for
        // having found no violations (.claude/rules/tests.md).
        #expect(source.contains("applicationDidFinishLaunching"))
        #expect(source.occurrences(of: "ToolTipDelay.install(") == 1)
    }
}
