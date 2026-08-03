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

    /// The stack that lays the sentence out adds NO spacing of
    /// its own — the frame's literals carry it.
    ///
    /// A per-segment gap is invisible as a bug in English, whose
    /// literals already have their own spaces (`" opens in "`),
    /// so it merely reads a little wide. In ja and ko the
    /// literal between two slots STARTS with a particle — `は`,
    /// `에` — that must hug the noun before it, and a stack gap
    /// tears it off; those are the four verb-final locales the
    /// whole `SentenceFrame` design exists for, so shipping a
    /// gap would undo the point of it in exactly the languages
    /// it was built for. It shipped as `spacing: 6` and the
    /// localization round caught it, not this suite.
    ///
    /// The needle is the ARGUMENT, whitespace-normalised, rather
    /// than the literal text `HStack(spacing: 0)`: `swift-format`
    /// wraps a declaration past 79 columns, and a scan for one
    /// spelling walks past the other.
    @Test("the sentence stack adds no spacing of its own")
    func sentenceStackAddsNoSpacing() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Sections/"
                            + "AppRuleRow.swift"
                    ),
                encoding: .utf8
            )
        )
        let marker = "private var sentence: some View"
        let start = try #require(
            source.range(of: marker),
            "AppRuleRow must still draw the sentence itself"
        )
        var characters = Array(source[start.upperBound...])
        var cursor = 0
        let body = try #require(
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "the sentence property must have a readable body"
        )
        // Assert the input before asserting about it: an empty
        // body would satisfy "contains no spacing: 6" for the
        // wrong reason.
        #expect(body.contains("ForEach(frame.segments)"))

        characters = Array(body)
        cursor = try #require(
            body.range(of: "HStack").map {
                body.distance(
                    from: body.startIndex,
                    to: $0.upperBound
                )
            },
            "the sentence must still lay out in an HStack"
        )
        let arguments = try #require(
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            ),
            "the HStack must carry an argument list"
        )
        #expect(
            arguments.filter { !$0.isWhitespace } == "spacing:0",
            Comment(
                rawValue:
                    "the sentence's HStack must add no spacing — "
                    + "the frame's literals own it, and a gap "
                    + "detaches the ja/ko particle from the noun "
                    + "it attaches to"
            )
        )
    }
}
