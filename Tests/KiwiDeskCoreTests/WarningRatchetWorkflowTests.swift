import Foundation
import Testing

/// The compiler-warning ratchet in `ci.yml` (#1594).
///
/// The ratchet is a mechanism with a long comment above it and
/// nothing holding it: reverting the step to a bare
/// `swift build` reds no test, leaves the comment describing an
/// enforcement that is gone, and re-opens the corpus #1501 swept
/// — which is rule-authoring.md's #614 shape one level up from
/// the rule it enforces.
///
/// Two-sided by construction. The positive clause alone passes
/// on a workflow that ratchets EVERYTHING, which is the change
/// packaging-and-release.md refuses: a new toolchain's
/// diagnostics must never be able to red a release.
@Suite("Compiler-warning ratchet (#1594)")
struct WarningRatchetWorkflowTests {
    /// The one call the `DeprecatedDeclaration` downgrade is cut
    /// for. Reserved for #1170, which #1501 deliberately left.
    private static let reservedDeprecation =
        "activateIgnoringOtherApps"

    private func ci() throws -> String {
        try workflowSource("ci.yml")
    }

    /// The debug `Build` step, and never another.
    ///
    /// `workflowStep` matches on `contains`, so `"Build"` also
    /// matches `- name: Build (release)` and any `Build…` step
    /// inserted above the real one. Either silently retargets
    /// every clause here onto the wrong step, reporting the
    /// ratchet gone while it is intact.
    ///
    /// Anchoring on the slice's OWN name covers both, where a
    /// `-c release` needle covered only the first: an inserted
    /// `Build docs` step runs neither `-c release` nor the
    /// ratchet, so it slipped through and redded with the
    /// misleading message (prover, 2026-09-22).
    ///
    /// `try #require` rather than `#expect` so the run STOPS
    /// here: `#expect` records the issue and continues, and the
    /// clause below then files its own "no longer ratchets"
    /// issue underneath the true cause.
    private func debugBuildStep() throws -> String {
        let step = try workflowStep("Build", in: try ci())
        let first =
            try #require(
                step.split(
                    separator: "\n",
                    omittingEmptySubsequences: false
                ).first
            )
            .trimmingCharacters(in: .whitespaces)
        try #require(
            first == "- name: Build",
            """
            'Build' matched \(first) — the debug step was \
            renamed, or a Build… step was inserted above it. \
            Every clause here would be reading the wrong step.
            """
        )
        return step
    }

    /// Whether `Sources/` still COMPILES the deprecated call the
    /// downgrade is cut for.
    ///
    /// The identifier must be read from CODE, never from text.
    /// It occurs twice in `AXHelper.swift` — the call, and a doc
    /// comment arguing for it — so a raw `contains` was
    /// satisfied by the comment alone and stayed green with the
    /// call deleted: a guard met by PROSE rather than by
    /// mechanism, inert in exactly the direction #1170 will take
    /// (prover, 2026-09-22).
    ///
    /// Dropping whole-line comments alone was not enough either.
    /// A #1170 patch most plausibly reads
    /// `.activate()  // was .activateIgnoringOtherApps`, whose
    /// note is TRAILING — proven to keep the clause green — as
    /// does `"activateIgnoringOtherApps"` in a literal. So this
    /// drops both: comment text from `//` to end of line, and
    /// the contents of string literals, quote-aware so a `//`
    /// inside a literal does not start a comment.
    ///
    /// The bound that remains, stated rather than guessed:
    /// block comments (`/* … */`) and multi-line string literals
    /// are not parsed, so an occurrence inside either still
    /// counts as code. `SourceScan.stripComments` handles those
    /// and carries a no-go-dark canary, but it lives in the GUI
    /// test target while this suite needs `workflowSource` from
    /// this one — so this is a narrower local reader by
    /// necessity, and the narrowness is the cost.
    private func deprecationIsCompiled() -> Bool {
        let root = scriptFixtureRepoRoot()
            .appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text =
                (try? String(contentsOf: url, encoding: .utf8))
                ?? ""
            for line in text.split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            where Self.code(in: line)
                .contains(Self.reservedDeprecation)
            {
                return true
            }
        }
        return false
    }

    /// One line's CODE: comment text and string-literal contents
    /// removed, the quotes themselves kept so the shape stays
    /// readable in a failure message.
    private static func code(in line: Substring) -> String {
        if line.trimmingCharacters(in: .whitespaces)
            .hasPrefix("//")
        {
            return ""
        }
        var inString = false
        var kept = ""
        var previous: Character?
        for character in line {
            if character == "\"", previous != "\\" {
                inString.toggle()
                kept.append(character)
                previous = character
                continue
            }
            if inString {
                previous = character
                continue
            }
            if character == "/", previous == "/" {
                kept.removeLast()
                break
            }
            kept.append(character)
            previous = character
        }
        return kept
    }

    @Test("The PR build errors on a new warning")
    func buildStepRatchets() throws {
        let step = try debugBuildStep()
        #expect(
            step.contains("-warnings-as-errors"),
            """
            ci.yml's Build step no longer ratchets: a new \
            compiler warning would land green (#1594)
            """
        )
    }

    /// The exemption, and why it is a clause rather than a
    /// comment: a ratchet on the release build would let a
    /// toolchain bump block a tag push, which
    /// packaging-and-release.md argues against and #1501
    /// deferred.
    @Test("The release build takes no ratchet")
    func releaseStepIsExempt() throws {
        let step = try workflowStep(
            "Build (release)",
            in: try ci()
        )
        #expect(
            !step.contains("-warnings-as-errors"),
            """
            the release build must not ratchet: a new \
            toolchain's diagnostics would block a release \
            (packaging-and-release.md)
            """
        )
    }

    /// The downgrade is an EXEMPTION, so it is held to the
    /// idiom `CiPathFilterTests` ▸ `exemptionsAreLive` states:
    /// one that outlives its reason silently widens the hole it
    /// was cut for.
    ///
    /// Its reason is a live deprecated call in `Sources/`. When
    /// #1170 removes it the downgrade must go with it, or every
    /// later deprecated-API use is permanently un-ratcheted with
    /// nothing to say so. Scoped to `Sources/` because that is
    /// what this step compiles — `swift build` does not build
    /// `Tests/` (#1596).
    @Test("The deprecation downgrade is still load-bearing")
    func downgradeIsLive() throws {
        let step = try debugBuildStep()
        let downgraded = step.contains("DeprecatedDeclaration")
        let reserved = deprecationIsCompiled()
        #expect(
            downgraded == reserved,
            """
            the DeprecatedDeclaration downgrade and the call it \
            excuses (\(Self.reservedDeprecation)) must appear \
            together: downgraded=\(downgraded) \
            callPresent=\(reserved). Remove the downgrade with \
            the call (#1170), or the ratchet stops seeing every \
            future deprecation.
            """
        )
    }
}
