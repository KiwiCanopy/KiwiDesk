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
    /// Both lists, separately. `push` and `pull_request` carry
    /// their own `paths:`, and the one that matters is
    /// `pull_request` — the gate has to fire on the PR that
    /// widens the list, not after it merges. Deleting just that
    /// one passed the first cut of this test.
    @Test("both triggers take the guide-route inputs")
    func bothTriggersWatchTheDeclaration() throws {
        let source = try workflowSource("site.yml")
        let inputs = [
            "Sources/KiwiDesk/SupportLinks.swift",
            "scripts/check-site-tokens.py",
        ]
        for input in inputs {
            #expect(
                source.occurrencesOfInput(input) == 2,
                Comment(
                    rawValue:
                        "site.yml names \(input) "
                        + "\(source.occurrencesOfInput(input))× — "
                        + "it needs one entry under push and one "
                        + "under pull_request, and the "
                        + "pull_request one is what makes the "
                        + "gate fire before a merge"
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
