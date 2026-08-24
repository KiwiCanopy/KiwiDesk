import Foundation
import Testing

/// One naming convention, three programs (#968).
///
/// `-unnotarized` is what `scripts/build-app.sh` renames an
/// artifact to when it cannot prove the bundle was stapled, and
/// two other programs read that name back:
/// `.github/workflows/release.yml` derives the superseded
/// sibling from it so a re-run's draft carries one artifact
/// rather than two, and `scripts/appcast-sync` refuses an
/// archive wearing it so Sparkle is never offered an update it
/// would download in full and then reject.
///
/// Past two mirrors of one string,
/// `.claude/rules/parity-tests.md` asks for a forget-proof test
/// rather than a third careful author — and this one is worse
/// than an ordinary mirror in both directions. Rename it in the
/// packager alone and the workflow's cleanup silently matches
/// nothing (a draft keeps both artifacts, and the one a person
/// reaches for is not something to find out) while the feed
/// starts offering un-notarized archives. Rename it in a reader
/// alone and the same, one consumer at a time. Nothing fails on
/// this machine in any of those cases.
///
/// **The packager is the authority and the suffix is read from
/// it**, never typed here: a literal in this file would be a
/// fourth copy wearing a guard's clothes
/// (`.claude/rules/rule-authoring.md` ▸ a number-pin must derive
/// the number).
///
/// **What this cannot see**: whether the three agree at
/// RUNTIME. It compares source text, so a reader that computed
/// the suffix some other way — or a packager whose rename never
/// fires — passes. What it forecloses is the drift that comes
/// from editing one program and not the others, which is the
/// one that has a way of happening.
@Suite("Unnotarized suffix parity (#968)")
struct UnnotarizedSuffixParityTests {
    /// The suffix as `build-app.sh` writes it, taken from the
    /// `require_stapled_or_rename` call sites that ARE the
    /// rename. Both artifacts must agree before it is used as
    /// an authority — two spellings in the packager is the same
    /// defect one level up.
    private func packagerSuffix() throws -> String {
        let script = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts")
                .appendingPathComponent("build-app.sh"),
            encoding: .utf8
        )
        // The CALL SITES, not the whole script: `-partial`
        // and `-notarize` are build-app.sh's own temporaries
        // and wear the same shape, so a scan over the file
        // reads three spellings of nothing.
        // Continuations are joined first — a call is one shell
        // line pretending to be three.
        let joined = script.replacingOccurrences(
            of: #"\s*\\\n\s*"#,
            with: " ",
            options: .regularExpression
        )
        let calls = joined.split(separator: "\n").filter {
            $0.contains("require_stapled_or_rename \"")
        }
        #expect(
            !calls.isEmpty,
            "build-app.sh no longer renames an unstapled artifact"
        )
        // The LAST argument of each call is the renamed name;
        // the one before it is the clean one. The suffix is
        // what the first carries and the second does not.
        var spellings = Set<String>()
        for call in calls {
            let quoted = call.split(separator: "\"")
                .enumerated()
                .filter { $0.offset % 2 == 1 }
                .map { String($0.element) }
            guard quoted.count >= 2 else { continue }
            let renamed = quoted[quoted.count - 1]
            let clean = quoted[quoted.count - 2]
            let stem = (renamed as NSString).deletingPathExtension
            let cleanStem = (clean as NSString)
                .deletingPathExtension
            #expect(
                stem.hasPrefix(cleanStem),
                "the renamed name is not the clean one plus a suffix"
            )
            spellings.insert(String(stem.dropFirst(cleanStem.count)))
        }
        #expect(
            spellings.count == 1,
            "build-app.sh spells the rename more than one way"
        )
        return try #require(
            spellings.first,
            "no renamed artifact name found in build-app.sh"
        )
    }

    @Test("every reader of the rename spells it the packager's way")
    func readersAgreeWithThePackager() throws {
        let suffix = try packagerSuffix()

        // The workflow derives the superseded sibling from it.
        let workflow = try workflowSource("release.yml")
        #expect(
            workflow.contains("*\(suffix))"),
            "release.yml's sibling_of does not read \(suffix)"
        )
        #expect(
            workflow.contains("%\(suffix)}"),
            "release.yml cannot recover the clean name"
        )

        // The feed refuses an archive wearing it.
        let sync = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts")
                .appendingPathComponent("appcast-sync"),
            encoding: .utf8
        )
        #expect(
            sync.contains(#"_UNNOTARIZED = "\#(suffix).zip""#),
            "appcast-sync refuses a suffix the packager does not write"
        )
    }
}
