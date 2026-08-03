import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The App Rules area against the census (#678 Phase 3, turn
/// 14a).
///
/// The promise here is WEAKER than in Bars or Layout Defaults,
/// and the guard says so rather than implying otherwise: this
/// area's one container is bespoke, because one census setting
/// draws a row per app. So these pin MEMBERSHIP — every
/// `.appRules` census key is recorded in an order list, and the
/// bespoke set is data — and nothing here claims that editing a
/// list moves anything on screen.
@Suite("App Rules render ↔ census parity")
struct AppRulesCensusRenderTests {
    private func censusRows(_ tier: SettingTier) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .appRules
                    && $0.placement.tier == tier
            }
        )
    }

    @Test("the at-rest rows are the census's")
    func atRest() {
        #expect(
            Set(AppRulesRowOrder.rulesAtRest) == censusRows(.atRest)
        )
        #expect(
            AppRulesRowOrder.rulesAtRest.count
                == Set(AppRulesRowOrder.rulesAtRest).count
        )
    }

    @Test("the title patterns are the census's show-more set")
    func showMore() {
        #expect(
            Set(AppRulesRowOrder.rulesShowMore)
                == censusRows(.showMore)
        )
    }

    /// The area's one container, derived from the census rather
    /// than restated — a second container would mount nowhere,
    /// since the section draws exactly one card.
    @Test("the area holds only the container it renders")
    func onlyOneContainer() {
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .appRules }
                .compactMap { $0.placement.container }
        )
        #expect(declared == [.rulesPerApp])
        // And it is declared bespoke: the guard above holds
        // membership only, and this is the data that says so.
        #expect(
            AppRulesRowOrder.bespokeContainers == declared,
            Comment(
                rawValue:
                    "a container of this area that is NOT bespoke "
                    + "would need a ForEach over an order list — "
                    + "and then the membership-only caveat in "
                    + "AppRulesRowOrder stops being true of it"
            )
        )
    }

    /// The sentence has to keep naming its facets somewhere a
    /// screen reader and the search index can reach, because it
    /// has no visible labels. The census names both rows by
    /// those keys, so losing the call sites would prune them
    /// from every locale — which `SettingKeyLocaleTests` catches
    /// only after the fact. Assert the keys are still the
    /// census's, and that the row authors them.
    @Test("the facets keep their names for search and VoiceOver")
    func facetsKeepTheirLabels() throws {
        let space = SettingKey.appRules(.appRules)
        let float = SettingKey.appRules(.floatRules)
        #expect(space.text.label == .key("app_rules.space"))
        #expect(float.text.label == .key("app_rules.float"))

        let source = try String(
            contentsOf: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/"
                        + "AppRuleRow+Facets.swift"
                ),
            encoding: .utf8
        )
        for key in ["app_rules.space", "app_rules.float"] {
            #expect(
                source.contains("accessibilityLabel(L(\"\(key)\"")
                    || source.contains("L(\"\(key)\""),
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
}
