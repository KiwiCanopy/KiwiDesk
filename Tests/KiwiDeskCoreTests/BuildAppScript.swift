import Foundation
import Testing

/// `scripts/build-app.sh` with its comment lines blanked, for the
/// suites that pin the script's ORDER (`SparklePackagingTests`,
/// `LicensePackagingTests`).
///
/// The strip is load-bearing rather than tidiness: without it a
/// COMMENTED-OUT entry satisfies every needle, so deleting
/// `Updater.app` from the signing list by commenting it passes —
/// proved by mutation before the strip existed. The same trap
/// `.claude/rules/gui.md` names, where a comment quoting a
/// deleted key stood in for its call site.
///
/// A line is dropped only when its first non-blank character is
/// `#`; a trailing `# …` on a code line survives, so a needle
/// parked in one would still satisfy a guard. Deliberate rather
/// than thorough: cutting mid-line would eat the plist heredoc's
/// `<key>` lines, which the assertions read.
func buildAppScriptWithoutComments() throws -> String {
    let url = scriptFixtureRepoRoot()
        .appendingPathComponent("scripts")
        .appendingPathComponent("build-app.sh")
    let raw = try String(contentsOf: url, encoding: .utf8)
    let text = raw.split(
        separator: "\n",
        omittingEmptySubsequences: false
    )
    .map { line -> Substring in
        let body = line.drop { $0 == " " || $0 == "\t" }
        return body.hasPrefix("#") ? "" : line
    }
    .joined(separator: "\n")

    // Assert the input before asserting anything about it: a
    // scan over an empty string passes every ordering check by
    // finding nothing, which reads exactly like passing.
    #expect(text.count > 1000, "build-app.sh looks empty")
    return text
}

/// Offset of `needle` in `text`, or a failed requirement.
func buildAppScriptIndex(
    _ needle: String,
    in text: String,
    _ comment: Comment
) throws -> Int {
    let range = try #require(text.range(of: needle), comment)
    return text.distance(from: text.startIndex, to: range.lowerBound)
}
