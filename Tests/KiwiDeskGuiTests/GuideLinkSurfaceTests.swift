import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the guide pointer is drawn, and that it is drawn from
/// one place (#1019, #1470).
///
/// Two sites, and neither stands in for the other: Home's
/// first-run banner reaches a new user once, and the Mac
/// Checklist's foot is the permanent route — the tour lands on
/// that card, so its own copy and About's went with #1470.
/// Dropping either is silent — the sentence still renders on
/// the other, every catalog key is still used, and nothing else
/// in the tree notices.
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
    /// pointer: both mount the one view.
    private static let surfaces = [
        ("Settings/HomeFirstRunBanner.swift", "GuideLink("),
        // The permanent route, and the one search reaches: the
        // mount AND its catalog anchor, since a `GuideLink()`
        // without the anchor is a pointer nobody can find by
        // typing "guide". The trade: the anchor is pinned as the
        // FIRST modifier on the mount, so a modifier inserted
        // between them reds this — move the anchor back to the
        // front rather than widening the needle, which is what
        // keeps the pair contiguous (tests.md).
        (
            "Settings/Sections/MacChecklistSection.swift",
            "GuideLink().searchAnchored("
                + "SettingsCatalog.macChecklist.guideLink)"
        ),
    ]

    /// The register bounds the TOTAL too: a third `GuideLink()`
    /// mount — About re-adding its own, a new section's foot —
    /// reads no `SupportLinks.guide` and trips no per-site
    /// needle, which is exactly the two-permanent-pointers drift
    /// the ruling exists to stop (architect-reviewer,
    /// 2026-09-15). `GuideLink(` with the paren is the MOUNT
    /// spelling; `GuideLink.` (the static members) is not
    /// counted.
    @Test("nothing else mounts the guide link")
    func noThirdMount() throws {
        var mounts: [String] = []
        for file in try SourceScan.swiftSources(under: tree)
        where file.lastPathComponent != "GuideLink.swift" {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count =
                text.components(separatedBy: "GuideLink(").count - 1
            if count > 0 {
                mounts.append(
                    "\(file.lastPathComponent)×\(count)"
                )
            }
        }
        #expect(
            mounts.sorted() == [
                "HomeFirstRunBanner.swift×1",
                "MacChecklistSection.swift×1",
            ],
            Comment(rawValue: "guide link mounts: \(mounts)")
        )
        #expect(mounts.count == Self.surfaces.count)
    }

    /// **The checklist's foot is the one that still works on
    /// day 30.** The banner is one-shot — `HomeFirstRunState
    /// .retire` ends it for good on dismiss or on the first save
    /// — so without a permanent route a user who dismissed the
    /// welcome had no way to the guide at all, which is the gap
    /// #1019 is titled after. Losing either is silent: the
    /// sentence still renders on the other, every catalog key is
    /// still used, and nothing else in the tree notices.
    @Test("both surfaces point at the guide")
    func everySurfaceOffersTheGuide() throws {
        for (surface, needle) in Self.surfaces {
            let text = try source(surface)
            let squashed = text.split(
                whereSeparator: \.isWhitespace
            ).joined()
            let mounted = squashed.contains(
                needle.split(whereSeparator: \.isWhitespace)
                    .joined()
            )
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
    /// each other.** `mac_checklist.guide` is the row label (a
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
            guard let row = catalog["mac_checklist.guide"],
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
                        + "guide \(row) in the search row and \(inline) "
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
    /// One reader: `GuideLink` owns the sentence form both
    /// surfaces draw (About's bare `Link` went with #1470).
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
            readers == ["GuideLink.swift"],
            Comment(
                rawValue:
                    "the guide URL is read in \(readers); the "
                    + "census is GuideLink alone"
            )
        )
    }
}
