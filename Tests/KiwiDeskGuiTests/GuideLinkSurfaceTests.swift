import Foundation
import Testing

@testable import KiwiDesk

/// Where the guide pointer is drawn, and that it is drawn from
/// one place (#1019).
///
/// Both sites are load-bearing and neither can stand in for the
/// other: the tour's closing card reaches a user who ran the
/// tour, Home's first-run banner reaches one who skipped it or
/// finished it months ago. Dropping either is silent — the
/// sentence still renders on the other screen, every catalog key
/// is still used, and nothing else in the tree notices.
///
/// The shape, not the words (`.claude/rules/tests.md`): that the
/// two surfaces mount the ONE view, and that nothing reaches the
/// URL around it. What the sentence says is the catalog's, and
/// retuning it must not red this suite.
@Suite("Guide link surfaces")
struct GuideLinkSurfaceTests {
    private var tree: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    private func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: tree.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    /// Keyed on the use SITES rather than on a total, so a
    /// second pointer in one file cannot cover a deletion in
    /// another — the failure a whole-tree count goes green on.
    ///
    /// Each site's needle is what proves THAT file draws the
    /// pointer: the tour's closing card takes the three facts
    /// directly (`OnboardingPage` owns its footer's layout), the
    /// banner mounts the view, and About draws a plain `Link`.
    private static let surfaces = [
        ("Onboarding/OnboardingView+Closing.swift", "GuideLink."),
        ("Settings/HomeFirstRunBanner.swift", "GuideLink("),
        (
            "Settings/Sections/GeneralSection+About.swift",
            "SupportLinks.guide"
        ),
    ]

    /// **The third site is the one that still works on day 30.**
    /// The other two are one-shot — the tour does not come back
    /// on its own, and `HomeFirstRunState.retire` ends the banner
    /// for good on dismiss or on the first save — so without a
    /// permanent route a user who dismissed the welcome had no
    /// way to the guide at all, which is the gap #1019 is titled
    /// after. Losing any one of the three is silent: the sentence
    /// still renders on the others, every catalog key is still
    /// used, and nothing else in the tree notices.
    @Test("all three surfaces point at the guide")
    func everySurfaceOffersTheGuide() throws {
        for (surface, needle) in Self.surfaces {
            #expect(
                try source(surface).contains(needle),
                Comment(
                    rawValue:
                        "\(surface) stopped pointing at the "
                        + "guide; the others still do, so nothing "
                        + "else reds"
                )
            )
        }
    }

    /// One home for the URL, and an exact census of who reaches
    /// it. A site composing its own would miss the locale
    /// narrowing `SupportLinks.guide` applies, which is how a
    /// `pt-BR` reader gets a 404 rather than English.
    ///
    /// Two readers, not one: `GuideLink` owns the sentence form
    /// that two surfaces draw, and About draws a bare `Link`
    /// whose label IS the destination — a sentence there would be
    /// prose in a card of one-word links.
    @Test("only the declared readers reach the guide URL")
    func theUrlHasOneReader() throws {
        let readers = try SourceScan.swiftSources(under: tree)
            .filter { file in
                let text = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                return text.contains("SupportLinks.guide")
            }
            .map { $0.lastPathComponent }
            .sorted()
        #expect(
            readers == [
                "GeneralSection+About.swift", "GuideLink.swift",
            ],
            Comment(
                rawValue:
                    "the guide URL is read in \(readers); the "
                    + "census is GuideLink and About"
            )
        )
    }
}
