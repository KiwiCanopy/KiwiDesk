import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A bar card's choices stay open and its numbers sit in one
/// drawer at its foot (#2507, design-decisions ▸ Choices stay
/// open). The census tiers the rows; these hold the tiering to
/// the rule.
@Suite("Bar cards: choices open, numbers in the drawer")
struct BarCardDepthTests {
    /// Every bar-card row drawn as a number — a slider, stepper or
    /// seconds row. A new number row joins here; review's to catch.
    private static let numbers: Set<SettingKey> = [
        .spaceBar(.spaceBarFrontAppTitleCap),
        .spaceBar(.spaceBarGlyphSpan),
        .spaceBar(.spaceBarGlyphGap),
        .spaceBar(.spaceBarSpringDelay),
        .appBar(.appBarTitleCap),
    ]

    private func rows(
        _ container: SettingsContainer,
        _ tier: SettingTier
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .bars
                    && $0.placement.container == container
                    && $0.placement.tier == tier
            }
        )
    }

    /// The drawer holds numbers alone, and a number stays open only
    /// where moving it would make a one-row drawer.
    @Test(
        "a bar card's drawer holds its numbers",
        arguments: [SettingsContainer.spaceBar, .appBar]
    )
    func numbersInTheDrawer(container: SettingsContainer) {
        let drawer = rows(container, .showMore)
        let open = rows(container, .atRest)
        #expect(drawer.isSubset(of: Self.numbers))
        let openNumbers = open.intersection(Self.numbers)
        let cardNumbers = openNumbers.union(drawer)
        #expect(
            openNumbers.isEmpty
                || (cardNumbers.count == 1 && drawer.isEmpty)
        )
    }

    /// A gated number leads Fine-tuning only under its gate, the
    /// last open choice above the drawer.
    @Test("Fine-tuning's first row hangs under its gate")
    func tuningLeadsUnderItsGate() throws {
        let first = try #require(BarsRowOrder.spaceBarTuning.first)
        let last = try #require(BarsRowOrder.spaceBar.last)
        #expect(first.placement.gate == .setting(last))
    }

    /// The census tiers a row behind the drawer; only the card's
    /// mount makes it reachable. The body draws the open rows and
    /// then the drawer once, and the drawer draws its order list.
    @Test("the Space Bar card mounts Fine-tuning at its foot")
    func tuningIsMounted() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Bars/"
                    + "SpaceBarCard.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        let count = { (needle: String) in
            source.components(separatedBy: needle).count - 1
        }
        #expect(count("rows(BarsRowOrder.spaceBar)tuningDisclosure}") == 1)
        #expect(count("tuningDisclosure") == 2)
        #expect(count("rows(BarsRowOrder.spaceBarTuning)") == 1)
        #expect(count("SettingsCatalog.bars.spaceBarTuning,") == 1)
    }
}
