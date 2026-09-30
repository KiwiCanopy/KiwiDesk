import Foundation
import Testing

@testable import KiwiDesk

/// Hover help is useless if it arrives after the pointer has
/// left, so the shortened `NSInitialToolTipDelay` is load-bearing
/// for every `GreyOut(help:)` sentence in Settings. Three parts,
/// because each fails on its own: the value, the store-and-marker
/// semantics that let a user's own delay win, and the fact that
/// launch actually installs it.
@Suite("Tooltip delay")
struct ToolTipDelayTests {
    private static let suitePrefix = "kiwidesk.tests.tooltip."

    /// A scratch suite cleaned on both sides: here, so a crashed
    /// run cannot seed it, and in each test's `defer`.
    private func scratchDefaults(_ name: String) -> UserDefaults {
        clean(name)
        return UserDefaults(suiteName: Self.suitePrefix + name)!
    }

    private func clean(_ name: String) {
        UserDefaults().removePersistentDomain(
            forName: Self.suitePrefix + name
        )
    }

    private func value(_ defaults: UserDefaults) -> Int? {
        defaults.object(forKey: ToolTipDelay.key) as? Int
    }

    private func marker(_ defaults: UserDefaults) -> Int? {
        defaults.object(forKey: ToolTipDelay.markerKey) as? Int
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

    /// The band argued in `docs/design-decisions.md` ▸ "Hover help
    /// appears sooner than AppKit's default": short enough that a
    /// reader who pauses is not left concluding there is nothing
    /// to read, long enough to need the pointer to rest. Its edges
    /// are the argument's, not the current value's, so a retune
    /// inside them stays green.
    @Test("the delay stays in its defended band")
    func delayInBand() {
        #expect((100...1000).contains(ToolTipDelay.milliseconds))
    }

    @Test("no stored value: install stores ours and the marker")
    func storesWhenAbsent() {
        let defaults = scratchDefaults("absent")
        defer { clean("absent") }
        ToolTipDelay.install(into: defaults)
        #expect(value(defaults) == ToolTipDelay.milliseconds)
        #expect(marker(defaults) == ToolTipDelay.milliseconds)
    }

    /// A value matching the marker is ours from an earlier
    /// release, so a retune reaches it.
    @Test("our earlier value moves to the current one")
    func updatesOwnEarlierValue() {
        let defaults = scratchDefaults("earlier")
        defer { clean("earlier") }
        let earlier = ToolTipDelay.milliseconds + 450
        defaults.set(earlier, forKey: ToolTipDelay.key)
        defaults.set(earlier, forKey: ToolTipDelay.markerKey)
        ToolTipDelay.install(into: defaults)
        #expect(value(defaults) == ToolTipDelay.milliseconds)
        #expect(marker(defaults) == ToolTipDelay.milliseconds)
    }

    /// A stored value the marker does not vouch for — no marker,
    /// or a marker naming another value — is the user's.
    @Test("a user's own delay wins", arguments: [nil, 700] as [Int?])
    func userValueWins(written: Int?) {
        let name = "user.\(written.map(String.init) ?? "none")"
        let defaults = scratchDefaults(name)
        defer { clean(name) }
        defaults.set(1234, forKey: ToolTipDelay.key)
        if let written {
            defaults.set(written, forKey: ToolTipDelay.markerKey)
        }
        ToolTipDelay.install(into: defaults)
        #expect(value(defaults) == 1234)
        #expect(marker(defaults) == written)
    }

    /// AppKit never reads the registration domain for this key
    /// (measured 2026-10-01, macOS 27), so a `register` here ships
    /// a delay that silently does nothing. Counted over the file,
    /// which the anchor clause proves was read.
    @Test("install stores rather than registers")
    func installDoesNotRegister() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let file = root.appendingPathComponent(
            "Sources/KiwiDesk/ToolTipDelay.swift"
        )
        let source = try String(contentsOf: file, encoding: .utf8)
        #expect(source.occurrences(of: "func install(") == 1)
        #expect(source.occurrences(of: "register(") == 0)
        #expect(source.occurrences(of: "registrationDomain") == 0)
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
