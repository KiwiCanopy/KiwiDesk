import Foundation
import Testing

@testable import KiwiDesk

/// The shape half of `SettingsTheme` — the `CGFloat` metrics.
///
/// `SettingsThemeWiringTests` gives every COLOUR a totality net:
/// each declared token is wired at a named render site or
/// deferred with a reason, derived from the source on one side
/// and the two lists on the other. Its parse keys on `= token(`,
/// so a metric was covered by nothing but whichever area suite
/// its author happened to write — Monitors wrote one, the palette
/// shelf wrote one, and the four radii that predate both are
/// guarded by neither. A third area adding a stroke was obliged
/// by nothing at all.
///
/// This is that net for the metrics, and deliberately the weaker
/// claim: it holds that each one is DRAWN somewhere, not that it
/// is drawn correctly. What "correctly" means is per-area and
/// belongs to the area's own chrome suite —
/// `MonitorsChromeWiringTests` pins the stand's whole ternary,
/// `PaletteShelfChromeTests` pins that the tile frame reads both
/// weights. A metric landing here without one of those is a
/// metric with a name and no argument.
@Suite("Settings theme metrics")
struct SettingsThemeMetricTests {
    /// Metric → a file that renders it. One named site each, in
    /// the sibling suite's idiom: the claim is "something draws
    /// this", not an exhaustive map.
    private let wired: [String: String] = [
        "cardRadius": "HomeCard.swift",
        "cardHeight": "HomeCard.swift",
        "cardHeightCompact": "HomeCard.swift",
        "plateHeight": "HomeCardPlate.swift",
        "sectionRadius": "SettingsSection.swift",
        "disclosureRadius": "SettingsDisclosure.swift",
        "chipRadius": "Chips.swift",
        "monitorCardStroke": "DisplayCard.swift",
        "monitorCardStrokeSelected": "DisplayCard.swift",
        "monitorStandScale": "MonitorsPicture.swift",
        "monitorStandMin": "MonitorsPicture.swift",
        "monitorStandMax": "MonitorsPicture.swift",
        "monitorNeckScale": "MonitorsPicture.swift",
        "monitorNeckMin": "MonitorsPicture.swift",
        "monitorNeckMax": "MonitorsPicture.swift",
        "paletteCardStroke": "PaletteTile.swift",
        "paletteCardStrokeApplied": "PaletteTile.swift",
        "containerStroke": "HomeCard.swift",
        "containerStrokeModeGated": "HomeCard.swift",
        "modeGatedStrokeOpacity": "HomeCard.swift",
        "panelWidth": "SettingsDetailPanel.swift",
        "contentMaxWidth": "SettingsView+Detail.swift",
        "searchNoticeFillOpacity": "SettingsSearchNotice.swift",
    ]

    /// Metric → why nothing draws it yet. Empty today, and kept
    /// rather than dropped: the colour half needed this list from
    /// its first day, and a metric shipped ahead of its consumer
    /// is the same trade `panel` and `onAccentKnob` already make.
    private let deferred: [String: String] = [:]

    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private let declaration = "SettingsTheme+Metrics.swift"

    /// Derived from production on one side and the two lists on
    /// the other, so a new metric belongs to exactly one of them
    /// or reds.
    @Test("the two lists cover every declared metric")
    func listsCoverEveryMetric() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: settingsDir.appendingPathComponent(
                    declaration
                ),
                encoding: .utf8
            )
        )
        var declared: Set<String> = []
        for line in source.split(separator: "\n") {
            guard let start = line.range(of: "static let "),
                let end = line.range(of: ": CGFloat =")
            else { continue }
            declared.insert(
                String(line[start.upperBound..<end.lowerBound])
            )
        }
        // A parse that found nothing would pass having read
        // nothing (#635).
        #expect(!declared.isEmpty)
        let listed = Set(wired.keys).union(deferred.keys)
        #expect(
            listed == declared,
            Comment(
                rawValue:
                    "unlisted: "
                    + declared.subtracting(listed).sorted()
                    .joined(separator: ", ")
                    + " · stale: "
                    + listed.subtracting(declared).sorted()
                    .joined(separator: ", ")
            )
        )
        #expect(Set(wired.keys).isDisjoint(with: deferred.keys))
        // The parse keys on a SPELLING, so a metric declared
        // `static var … : CGFloat { }` would sit outside the net
        // while looking listed. Tie it to the file's own census:
        // every `CGFloat` in the metrics file is one of these
        // declarations (the colour file keeps `srgb` and its
        // parameters — the split at the §2.1 ceiling moved the
        // shapes out whole). The other evasion is a metric
        // typed `Double`, which adds no `CGFloat` mention at
        // all — so that spelling is refused outright rather
        // than counted. A geometry number in this file is a
        // `CGFloat`; SwiftUI's own metrics are.
        #expect(
            !source.contains(": Double"),
            Comment(
                rawValue:
                    "a `Double` metric evades the CGFloat census"
            )
        )
        let mentions =
            source.components(separatedBy: "CGFloat")
            .count - 1
        // One import line (`import CoreGraphics`) mentions no
        // CGFloat, so the count is exactly the declarations.
        #expect(
            mentions == declared.count,
            Comment(
                rawValue:
                    "\(mentions) CGFloat mentions against "
                    + "\(declared.count) parsed declarations — "
                    + "a metric is declared in a shape this "
                    + "parse cannot see"
            )
        )
    }

    /// A metric named for another plus a STATE suffix is half of
    /// a pair, and a pair is the shape whose whole point is that
    /// the two weights stay apart — so some suite has to name
    /// both together. That is the strong claim this net defers,
    /// and deferring it to "the area will write one" is how a
    /// third area lists a stroke pair here, points at its view,
    /// and writes no chrome suite at all. The four radii carry no
    /// state suffix and correctly escape.
    @Test("a state-suffixed metric pair is guarded together")
    func metricPairsAreGuardedTogether() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let suites = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Tests")
        )
        .map {
            SourceScan.stripComments(
                (try? String(contentsOf: $0, encoding: .utf8))
                    ?? ""
            )
        }
        #expect(suites.count > 100)
        for metric in wired.keys {
            guard
                let base = wired.keys.first(where: {
                    $0 != metric && metric.hasPrefix($0)
                })
            else { continue }
            #expect(
                suites.contains {
                    $0.contains("SettingsTheme.\(metric)")
                        && namesExactly($0, base)
                },
                Comment(
                    rawValue:
                        "no suite names both \(base) and "
                        + "\(metric) — the pair's two weights "
                        + "can drift together unseen"
                )
            )
        }
    }

    @Test("every wired metric is drawn by the file that claims it")
    func wiredMetricsAreDrawn() throws {
        for (metric, file) in wired {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: try site(named: file),
                    encoding: .utf8
                )
            )
            #expect(
                source.contains("SettingsTheme.\(metric)"),
                Comment(
                    rawValue:
                        "\(file) no longer draws "
                        + "SettingsTheme.\(metric) — either it "
                        + "moved (repoint the needle) or the "
                        + "metric went dead."
                )
            )
        }
    }

    /// Vacuous while `deferred` is empty, deliberately and
    /// stated rather than hidden: only the file floor is live
    /// today. It ships now so a metric deferred later meets a
    /// working check instead of an author remembering to write
    /// one — the colour half needed exactly this list from its
    /// first day.
    @Test("a deferred metric really has no consumer")
    func deferredMetricsAreUnused() throws {
        var drawn: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: settingsDir)
        where file.lastPathComponent != declaration {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            for metric in deferred.keys
            where source.contains("SettingsTheme.\(metric)") {
                drawn.append(
                    "\(metric) in \(file.lastPathComponent)"
                )
            }
        }
        // The floor its sibling carries, and for the same reason:
        // this test can only fail by finding something, so
        // reading nothing is indistinguishable from passing.
        #expect(scanned > 50)
        #expect(drawn.isEmpty, Comment(rawValue: drawn.joined()))
        for (metric, reason) in deferred {
            #expect(!reason.isEmpty, Comment(rawValue: metric))
        }
    }

    /// `SettingsTheme.paletteCardStroke` is a PREFIX of
    /// `…StrokeApplied`, so a bare `contains` for the base name
    /// is implied by the suffixed one and the `&&` collapses to
    /// one claim — a suite needling only the applied branch left
    /// the rest weight named nowhere in `Tests/` and this guard
    /// passed (guard-prover, 2026-08-09). The base must be
    /// followed by something that cannot continue an identifier.
    private func namesExactly(
        _ source: String,
        _ base: String
    ) -> Bool {
        let needle = "SettingsTheme.\(base)"
        var rest = Substring(source)
        while let hit = rest.range(of: needle) {
            let after = rest[hit.upperBound...].first
            if after == nil
                || !(after!.isLetter
                    || after!.isNumber || after! == "_")
            {
                return true
            }
            rest = rest[hit.upperBound...]
        }
        return false
    }

    private func site(named file: String) throws -> URL {
        let match = try SourceScan.swiftSources(under: settingsDir)
            .first { $0.lastPathComponent == file }
        return try #require(match, Comment(rawValue: file))
    }
}
