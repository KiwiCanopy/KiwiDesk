import Foundation
import Testing

/// A workflow's executable YAML, with comments removed.
///
/// Shared because the stripping is the load-bearing part and a
/// divergent copy would silently weaken whichever suite got the
/// weaker one — the drift ground the other ratified helpers in
/// `.claude/rules/tests.md` name. Three assertions in the first
/// cut of the #874 guards were satisfied by PROSE rather than by
/// mechanism: the signing step's own comment names
/// `--ed-key-file -` while explaining why `-s` is wrong, and the
/// sync workflow's header lists `site/public/appcast.xml` while
/// explaining why it travels with the notes. Each would have
/// kept passing with the mechanism deleted and only the argument
/// for it left behind.
///
/// **Continuations are joined before comments are stripped, and
/// that order is the fix rather than a tidy-up.** A `\`-wrapped
/// command is one shell line pretending to be several, so quote
/// parity counted per physical line is wrong on every one of
/// them — which is how a needle parked in a trailing comment
/// survived the first version of this helper. Joining also stops
/// every needle depending on where the YAML happens to wrap.
///
/// Asserts its own input is non-empty: a renamed or moved
/// workflow would otherwise make every needle "not found" and
/// each caller would pass for having read nothing.
func workflowSource(_ name: String) throws -> String {
    let text = try String(
        contentsOf: scriptFixtureRepoRoot()
            .appendingPathComponent(".github")
            .appendingPathComponent("workflows")
            .appendingPathComponent(name),
        encoding: .utf8
    )
    #expect(
        !text.isEmpty,
        "\(name) is missing: every needle would pass vacuously"
    )
    let joined = text.replacingOccurrences(
        of: #"\s*\\\n\s*"#,
        with: " ",
        options: .regularExpression
    )
    return
        joined
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(strippingComment)
        .joined(separator: "\n")
}

/// One line with its comment removed — WHOLE-LINE and TRAILING
/// alike.
///
/// A `#` counts as a comment only when it follows whitespace AND
/// the quotes before it on the line are balanced. Both clauses
/// are load-bearing against real lines in these workflows:
/// `"${TAG#v}"` is parameter expansion inside a quoted string,
/// not a comment, and it is neither preceded by whitespace nor
/// outside quotes.
private func strippingComment(_ line: Substring) -> String {
    if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
        return ""
    }
    var quotes = 0
    var kept = ""
    var previous: Character?
    for character in line {
        if character == "\"" || character == "'" { quotes += 1 }
        if character == "#", quotes % 2 == 0,
            previous?.isWhitespace == true
        {
            break
        }
        kept.append(character)
        previous = character
    }
    return kept
}

/// One named step's own block: from its `- name:` line to the
/// next step's.
///
/// Scoping is the whole point, and it was learned the expensive
/// way. A needle asserted against the WHOLE workflow can be
/// satisfied by a step that is not the one under test:
/// `ARCHIVE: ${{ steps.archive.outputs.path }}` occurs in both
/// the draft step and the Sparkle signing step, so a guard
/// meaning "the draft step is handed the archive" stayed green
/// with the draft step's own copy deleted. Read the step that
/// must carry the mechanism, not the file that happens to.
func workflowStep(
    _ name: String,
    in yaml: String
) throws -> String {
    let lines = yaml.split(
        separator: "\n",
        omittingEmptySubsequences: false
    )
    let start = try #require(
        lines.firstIndex { $0.contains("- name: \(name)") },
        "no step named \(name) in this workflow"
    )
    var end = lines.count
    for index in (start + 1)..<lines.count {
        let line = lines[index]
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            continue
        }
        // The next step, OR anything shallower than a step:
        // the next job, or a job-level key. Stopping only on
        // the next step fails OPEN for the LAST step in the
        // file, whose slice would then run to EOF and let a
        // job appended below satisfy one of its needles.
        let indent = line.prefix { $0 == " " }.count
        if line.hasPrefix("      - ") || indent <= 6 {
            end = index
            break
        }
    }
    return lines[start..<end].joined(separator: "\n")
}
