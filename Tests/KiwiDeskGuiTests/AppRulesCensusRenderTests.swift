import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The App Rules area against the census (#678 Phase 3, turn
/// 14a).
///
/// The promise here is WEAKER than in Bars or Layout Defaults,
/// and these say so rather than implying otherwise: this area's
/// one container is bespoke, because one census setting draws a
/// row per app. There is no order list to pin — an order list
/// here would be a second copy of a census filter — so what is
/// guarded is that the bespoke declaration stays true of the
/// tree, and that the sentence keeps naming its facets somewhere
/// a screen reader and the search index can reach.
@Suite("App Rules render ↔ census parity")
struct AppRulesCensusRenderTests {
    /// The area's one container, derived from the census — a
    /// second one would mount nowhere, since the section draws
    /// exactly one card.
    @Test("the area holds only the container it renders")
    func onlyOneContainer() {
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .appRules }
                .compactMap { $0.placement.container }
        )
        #expect(declared == [.rulesPerApp])
    }

    /// The bespoke claim, read off the TREE rather than restated
    /// against another literal (Phase 3 ruling 5: a guard over a
    /// literal restated against a literal documents, it does not
    /// detect). A container is bespoke exactly when nothing
    /// `ForEach`es an order list for it — so the check is that
    /// this area's views declare no such list to walk.
    @Test("the bespoke container really has no order list")
    func bespokeMeansNoOrderList() throws {
        #expect(
            AppRulesRowOrder.bespokeContainers == [.rulesPerApp]
        )
        // Whitespace-normalised, and the AppRules directory is
        // scanned WHOLE rather than by filename: guard-prover
        // walked three spellings past the first cut — a missing
        // space (`:[SettingKey]`, which lints as a warning and
        // ships, since the exit code decides), a declaration
        // wrapped across lines (which is what swift-format
        // itself produces past 79 columns, with no warning at
        // all), and a list in a file whose name does not start
        // with "AppRule".
        let root = SourceScan.repoRoot(from: #filePath)
        var files: [URL] = try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/AppRules"
            )
        )
        files += try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections"
            )
        ).filter { $0.lastPathComponent.hasPrefix("AppRule") }
        #expect(files.count >= 5)
        var declaresList = false
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let squashed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            if squashed.contains("[SettingKey]=[") {
                declaresList = true
            }
        }
        #expect(
            !declaresList,
            Comment(
                rawValue:
                    "an App Rules file declares a [SettingKey] "
                    + "order list — if a container here is now "
                    + "rendered from one it is no longer bespoke, "
                    + "and bespokeContainers must say so"
            )
        )
    }

    /// The sentence has to keep naming its facets somewhere a
    /// screen reader and the search index can reach, because it
    /// has no visible labels. The census names both rows by
    /// those keys, so losing the call sites would prune them
    /// from every locale — which `SettingKeyLocaleTests` catches
    /// only after the fact.
    @Test("the facets keep their names for search and VoiceOver")
    func facetsKeepTheirLabels() throws {
        let space = SettingKey.appRules(.appRules)
        let float = SettingKey.appRules(.floatRules)
        #expect(space.text.label == .key("app_rules.space"))
        #expect(float.text.label == .key("app_rules.float"))

        // The needle is the `.accessibilityLabel(L(...))` SHAPE,
        // not a mention of the key. An earlier cut allowed
        // either, and guard-prover swapped the modifier for a
        // `.help(...)` carrying the same key: the menu lost its
        // accessibility name entirely — the exact harm named
        // above — and the guard stayed green because the key was
        // still somewhere in the file. Comments are stripped for
        // the same reason: a commented-out call site also
        // satisfied the weak half.
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Sections/"
                            + "AppRuleRow+Facets.swift"
                    ),
                encoding: .utf8
            )
        )
        for key in ["app_rules.space", "app_rules.float"] {
            #expect(
                source.contains(
                    "accessibilityLabel(L(\"\(key)\""
                ),
                Comment(
                    rawValue:
                        "\(key) is the census label for a facet "
                        + "the sentence draws without a visible "
                        + "label — it must stay authored as the "
                        + "menu's accessibility name"
                )
            )
        }
    }

    /// Naming the control took its VALUE away, and only from the
    /// people who needed the name (#678 Phase 4 pass 10, turn 20a
    /// rule 3).
    ///
    /// `.accessibilityLabel` REPLACES the name SwiftUI derives,
    /// and for a `Menu` that derived name is its current choice.
    /// So the modifier the test above requires is exactly what
    /// silenced "which space" — a sighted reader still reads the
    /// choice out of the sentence, which is why nothing looked
    /// wrong. Both halves are now required together, and the pair
    /// is why they are asserted in one test: a future edit that
    /// drops the value to fix an over-verbose announcement has to
    /// meet this comment.
    ///
    /// The needle is the modifier's shape over stripped source,
    /// the same lens and for the same reason as the label half.
    @Test("the facets announce their value, not just their name")
    func facetsAnnounceTheirValue() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Sections/"
                            + "AppRuleRow+Facets.swift"
                    ),
                encoding: .utf8
            )
        )
        // Keyed on each menu's OWN value expression, not on a
        // count of call sites. A bare count of two is satisfied
        // by both values landing on one control while the other
        // menu has none — guard-prover did exactly that and the
        // first cut stayed green (2026-08-11), which is the drift
        // its comment claimed to catch. The expressions differ
        // per menu, so one missing reds however many the file
        // holds in total.
        for value in ["spaceFacetLabel", "floatLabel"] {
            #expect(
                source.contains(".accessibilityValue(\(value))"),
                Comment(
                    rawValue:
                        "the facet menu whose choice is "
                        + "`\(value)` no longer announces it — an "
                        + "`.accessibilityLabel` on a Menu "
                        + "replaces the choice VoiceOver would "
                        + "otherwise read, so the value has to be "
                        + "given back explicitly"
                )
            )
        }
    }
}
