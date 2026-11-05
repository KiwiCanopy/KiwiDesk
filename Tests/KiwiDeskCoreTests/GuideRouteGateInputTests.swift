import Foundation
import Testing

/// The site gate must fire when the APP's guide-route list moves
/// (#1019).
///
/// `scripts/check-site-tokens.py` ▸ `check_guide_routes` parses
/// `guideRoutes` out of `Sources/KiwiDesk/SupportLinks.swift` and
/// checks it against the built pages, so `site.yml` takes that
/// file — and the script itself — as path inputs. Lose either
/// entry and the widening lands unchecked, then the gate reds
/// later on somebody else's PR about a route they never touched.
///
/// **In the Core target because that is where the
/// comment-stripping workflow reader lives** (`tests.md`). The
/// first cut of this read the raw YAML from the GUI suite, and
/// `guard-prover` showed it green after BOTH `paths:` entries
/// were deleted — the needle was satisfied by the file's own
/// comment arguing for the mechanism.
@Suite("Guide route gate inputs")
struct GuideRouteGateInputTests {
    /// The one list: `push`'s `paths:`, which the `changes` job
    /// applies to a PR, so the gate fires on the PR that widens
    /// the list and not after it merges (`SiteGateRequiredTests`).
    @Test("the site's list takes the guide-route inputs")
    func theListWatchesTheDeclaration() throws {
        let source = try workflowSource("site.yml")
        let inputs = [
            "Sources/KiwiDesk/SupportLinks.swift",
            "scripts/check-site-tokens.py",
            // The site gate RUNS this one and the check above
            // IMPORTS it (#1232), so it is an input to the gate
            // twice over — and the macOS suites shell out to it
            // without ever running it against the real corpus.
            "scripts/unreleased-strip",
        ]
        for input in inputs {
            #expect(
                source.occurrencesOfInput(input) == 1,
                Comment(
                    rawValue:
                        "site.yml names \(input) "
                        + "\(source.occurrencesOfInput(input))× — "
                        + "it needs one entry in push's paths, "
                        + "which the changes job also applies to "
                        + "a PR"
                )
            )
        }
    }
}

extension String {
    fileprivate func occurrencesOfInput(_ needle: String) -> Int {
        split(separator: "\n")
            .filter {
                $0.trimmingCharacters(in: .whitespaces)
                    == "- \"\(needle)\""
            }
            .count
    }
}
