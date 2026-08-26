import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the guide pointer is drawn, and that it is drawn from
/// one place (#1019).
///
/// Both sites are load-bearing and neither can stand in for the
/// other: the tour's closing card reaches a user who ran the
/// tour, Home's first-run banner reaches one who closed it
/// early or
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
        // `GuideLink.open` — the NAVIGATION, not the sentence.
        // A bare `GuideLink.` was satisfied by `hint: GuideLink
        // .prose` alone, so deleting the `hintLink:` argument
        // left the card rendering the words with nothing to
        // click and this suite green (`guard-prover`,
        // 2026-08-26) — a regression the source comment three
        // lines above it records having already shipped once.
        (
            "Onboarding/OnboardingView+Closing.swift",
            "GuideLink.open"
        ),
        ("Settings/HomeFirstRunBanner.swift", "GuideLink("),
        (
            "Settings/Sections/GeneralSection+About.swift",
            // The MOUNT, not the declaration. `SupportLinks
            // .guide` matches inside `var guideLink`'s own body,
            // so deleting the bare `guideLink` line from the
            // card's `VStack` — which removes the app's only
            // permanent route to the guide — left this suite and
            // three catalog guards green (`code-reviewer`,
            // 2026-08-26). gui.md states the rule this broke:
            // key a needle on the site that USES the value.
            // Matched as a whole stripped LINE because that is
            // what a bare mount is; the declaration reads
            // `@ViewBuilder var guideLink: some View {`.
            "guideLink"
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
            let text = try source(surface)
            let mounted =
                text.contains(needle)
                && (needle != "guideLink"
                    || text.split(separator: "\n").contains {
                        $0.trimmingCharacters(in: .whitespaces)
                            == needle
                    })
            #expect(
                mounted,
                Comment(
                    rawValue:
                        "\(surface) stopped pointing at the "
                        + "guide; the others still do, so nothing "
                        + "else reds"
                )
            )
        }
    }

    /// **Two keys name ONE destination, so they are pinned to
    /// each other.** `general.about.guide` is the row label (a
    /// bare noun, "Guide"); `common.read_guide` is the same noun
    /// inside a sentence, where most languages want an article
    /// ("das Handbuch", "la guía"). They cannot be one key —
    /// German's row would read "das Handbuch" — but the diff's
    /// own argument depends on them agreeing: a reader who clicks
    /// "Handbuch" must land on a page called "Handbuch".
    ///
    /// Nothing else can see this. `placeholder_drift` compares
    /// specifiers, the residue guard reads one value at a time,
    /// and both keys are well-formed however they drift — which
    /// is `localization.md`'s one-concept-one-word failure in its
    /// exact-collision shape, and a later round touching one key
    /// and not the other is exactly how it arrives.
    ///
    /// The test is CONTAINMENT rather than equality, which is
    /// what makes it survive an article and a capital: the row's
    /// noun appears inside the sentence's mention, case-folded.
    /// A locale that answers the two with different words fails
    /// it; a locale that inflects around one shared noun passes.
    @Test("both guide names use one noun in every catalog")
    @MainActor
    func theTwoGuideNamesAgree() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        let catalogs = try FileManager.default
            .contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
        // The walk takes its subject from the listing, so a
        // DELETED catalog is a shorter loop rather than a
        // failure. Derived from the shipped locales plus English,
        // never a literal (`rule-authoring.md`: a number-pin
        // derives the number).
        #expect(
            catalogs.count
                == LocalizationManager.shared.available.count + 1
        )
        for file in catalogs {
            let catalog = try catalog(
                dir,
                file.deletingPathExtension().lastPathComponent
            )
            // **Both translated, or neither — a HALF-translated
            // pair is not drift and must not red.** A catalog
            // that carries one key and not the other falls back
            // to English for the missing half, so the row would
            // read "Guide" against a sentence reading "das
            // Handbuch" and containment would fail on copy nobody
            // has got wrong yet. That is a normal state between
            // `extract-keys` and `merge-keys`, and a guard that
            // reds there is a guard people learn to ignore
            // (`code-reviewer` asked; ruled 2026-08-26).
            guard let row = catalog["general.about.guide"],
                let inline = catalog["common.read_guide"]
            else { continue }
            #expect(
                !row.isEmpty && !inline.isEmpty,
                Comment(rawValue: "\(file.lastPathComponent)")
            )
            #expect(
                inline.lowercased().contains(row.lowercased()),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) calls the "
                        + "guide \(row) in About and \(inline) "
                        + "in the sentence — two words for one "
                        + "destination"
                )
            )
        }
    }

    private func catalog(
        _ dir: URL,
        _ locale: String
    ) throws -> [String: String] {
        let data = try Data(
            contentsOf: dir.appendingPathComponent(
                "\(locale).json"
            )
        )
        return try JSONDecoder().decode(
            [String: String].self,
            from: data
        )
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
