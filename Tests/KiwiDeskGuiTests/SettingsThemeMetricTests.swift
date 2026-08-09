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

    private let declaration = "SettingsTheme.swift"

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

    private func site(named file: String) throws -> URL {
        let match = try SourceScan.swiftSources(under: settingsDir)
            .first { $0.lastPathComponent == file }
        return try #require(match, Comment(rawValue: file))
    }
}
