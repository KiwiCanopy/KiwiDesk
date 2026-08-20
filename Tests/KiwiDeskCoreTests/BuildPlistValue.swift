import Foundation

/// Reads one `<string>` value out of the `Info.plist` heredoc in
/// `scripts/build-app.sh`.
///
/// The packager is the one owner of what every shipped bundle
/// declares, so a suite asserting anything about a plist key has
/// to READ it there rather than restate it. A literal in a test
/// agrees with itself forever: raise the deployment target or
/// move the feed, and the guard keeps passing against the value
/// that used to be true.
///
/// Two suites need this (`AppcastParserTests` for the system
/// floor, `AppcastWorkflowTests` for the feed URL), which is the
/// point at which `.claude/rules/parity-tests.md` prefers one
/// reader over a second copy of the parse.
///
/// Returns nil when the key is absent, so the caller can record a
/// specific failure rather than assert against an empty string.
func buildAppPlistValue(_ key: String) throws -> String? {
    let script = try String(
        contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("scripts")
            .appendingPathComponent("build-app.sh"),
        encoding: .utf8
    )
    guard let keyRange = script.range(of: "<key>\(key)</key>")
    else { return nil }
    let rest = keyRange.upperBound..<script.endIndex
    guard let open = script.range(of: "<string>", range: rest)
    else { return nil }
    let afterOpen = open.upperBound..<script.endIndex
    guard let close = script.range(of: "</string>", range: afterOpen)
    else { return nil }
    return String(script[open.upperBound..<close.lowerBound])
}
