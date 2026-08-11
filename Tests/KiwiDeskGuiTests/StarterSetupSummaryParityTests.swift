import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Starter preset's summary must not name the layouts it lays
/// down — the guard that replaces a parity check, by removing the
/// second copy rather than comparing it.
///
/// **Why there was ever a pair.** The ladder's summary named its
/// rungs one by one, so the English copy and the mode list were
/// two hand-written copies of one thing, and they drifted silently
/// and in the direction nothing could see. `016cc50a` — a commit
/// about the activation policy — flipped rung 2 from `.stack` to
/// `.bsp` while every piece of prose kept saying "Stack": the
/// Settings summary, all eleven catalogs, and the user guide. No
/// gate could catch it. `extract-keys --check` compares keys
/// against call sites and the English literal was untouched, so it
/// stayed green; the catalogs were not stale, they were faithfully
/// translating a sentence that had become false.
///
/// **Why the pair is gone.** Since #678 Phase 4 pass 11 the setup
/// derives its modes from the shapes of the connected screens, so
/// a sentence naming them would be a different sentence on every
/// Mac and could not be authored at all. The summary states the
/// rule instead. That makes the old drift impossible rather than
/// merely watched — but only for as long as nobody adds a mode
/// name back, which is what this suite now watches.
///
/// The mode a preset assigns is not a detail a user can shrug off:
/// picking Starter is how someone learns what the layouts *are*,
/// so a summary that names the wrong one teaches the wrong name
/// for the layout they are looking at. A summary that names none
/// cannot.
@Suite("Starter summary independence", .serialized)
@MainActor
struct StarterSetupSummaryParityTests {
    private var shapes: [CGSize] {
        [
            CGSize(width: 1728, height: 1117),
            CGSize(width: 2560, height: 1440),
            CGSize(width: 3440, height: 1440),
            CGSize(width: 1440, height: 2560),
        ]
    }

    /// Setups whose derived modes differ, so a summary that
    /// leaked ANY of them is caught whichever shape leaked it —
    /// and whose screen COUNTS differ too.
    ///
    /// The count matters and its absence was a hole: an earlier
    /// cut listed four one-screen setups, so a
    /// `where screenCount == 1` arm returning a second key was
    /// taken by every fixture and the "one summary, whatever the
    /// screens" test could not see it at all (guard-prover,
    /// 2026-08-11). Varying the shape proves one thing, varying
    /// the count another.
    private var setups: [[CGSize]] {
        (1...shapes.count).map { Array(shapes.prefix($0)) }
    }

    @Test("The summary names no layout mode")
    func summaryNamesNoMode() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }

        let names = LayoutMode.allCases.map(\.displayName)
        #expect(!names.isEmpty)
        for sizes in setups {
            let summary = StarterSetup.standardLayout(sizes: sizes)
                .displaySummary
            #expect(!summary.isEmpty)
            for name in names {
                #expect(
                    !summary.contains(name),
                    """
                    The Starter summary names "\(name)", which is \
                    a layout this setup may not lay down — the \
                    modes come from the screens. Summary: \
                    "\(summary)"
                    """
                )
            }
        }
    }

    /// Vacuity: the sweep above proves nothing if the setups all
    /// derive the same modes, since then "names no mode" would be
    /// one claim rather than four.
    @Test("The four setups really do derive different modes")
    func setupsDiffer() {
        let derived = setups.map { sizes in
            StarterSetup.spaceModes(sizes: sizes)
        }
        #expect(Set(derived.map { String(describing: $0) }).count > 1)
    }

    /// The same claim over the SHIPPED CATALOGS, which the
    /// rendered-string tests above cannot reach.
    ///
    /// `LocalizationManager.select("en")` leaves `effectiveLocale`
    /// nil by design, so every test that renders a string reads
    /// only the inline call-site English — the ten translations
    /// are never consulted. That is exactly the drift this
    /// suite's own history describes: `016cc50a` left eleven
    /// catalogs faithfully saying "Stack" about a rung that had
    /// become `.bsp`. So the catalogs get their own read
    /// (guard-prover, 2026-08-11 — putting a mode name into
    /// `en.json` left the whole suite green).
    ///
    /// Matched case-insensitively and against every locale's OWN
    /// name for each mode, since a translated summary would leak
    /// a translated mode name, not the English one.
    @Test("no catalog's Starter summary names a layout mode")
    func catalogsNameNoMode() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        let files = try FileManager.default
            .contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        var read = 0
        var carried = 0
        for file in files {
            let data = try Data(contentsOf: file)
            let catalog =
                try JSONSerialization.jsonObject(with: data)
                as? [String: String] ?? [:]
            read += 1
            guard
                let summary = catalog["presets.starter.summary"]
            else { continue }
            carried += 1
            // Each mode's name AS THIS LOCALE WRITES IT, falling
            // back to the English key name where a locale has not
            // translated it.
            for mode in LayoutMode.allCases {
                let key = "layout.\(mode.rawValue).name"
                let name = catalog[key] ?? mode.rawValue
                guard name.count > 2 else { continue }
                #expect(
                    !summary.lowercased()
                        .contains(name.lowercased()),
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) names "
                            + "\"\(name)\" in the Starter "
                            + "summary — the modes come from the "
                            + "screens, so no catalog may name "
                            + "one. Summary: \"\(summary)\""
                    )
                )
            }
        }
        // A scan that read nothing passes for having found
        // nothing (#635) — so the floor is on the CATALOGS READ,
        // not on how many carry the key.
        //
        // Those are different claims, and the second one is
        // wrong: a key mid-translation-round is absent from every
        // locale by design and falls back to English per key.
        // Requiring each catalog to carry it would make a
        // half-translated locale a test failure, which
        // `PresetSummaryCoverageTests` already argues against in
        // as many words. What must not happen is the scan reading
        // no files at all.
        #expect(
            read >= 10,
            Comment(
                rawValue:
                    "read only \(read) catalog(s) — the locale "
                    + "directory moved and this guard went quiet"
            )
        )
        // …and English must still carry it, or there is no key
        // left to be wrong about.
        #expect(
            carried >= 1,
            Comment(
                rawValue:
                    "no catalog carried presets.starter.summary "
                    + "— the key was renamed or retired"
            )
        )
    }

    /// The one sentence is the same sentence everywhere, which is
    /// what "states the rule" means — a `where screenCount` arm
    /// re-introducing a per-count variant reds here.
    @Test("One summary, whatever the screens")
    func summaryIsOneSentence() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let summaries = setups.map {
            StarterSetup.standardLayout(sizes: $0).displaySummary
        }
        #expect(Set(summaries).count == 1)
    }
}
