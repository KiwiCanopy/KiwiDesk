import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Pocket card (#2680): its keys moved in from Size & float,
/// what it holds (#2678) and its placement rows, none greyed.
@Suite("Pocket card")
@MainActor
struct PocketGroupTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("the keys left Size & float for the Pocket card")
    func keysMoved() {
        let pocketKeys: [SettingKey] = [
            .shortcuts(.pocket), .shortcuts(.pocketWindow),
        ]
        #expect(ShortcutsRowOrder.pocketAtRest == pocketKeys)
        for key in pocketKeys {
            #expect(
                !ShortcutsRowOrder.sizeAndFloatAtRest.contains(key)
            )
            #expect(key.placement.container == .pocket)
        }
        for key in ShortcutsRowOrder.pocketList {
            #expect(key.placement.container == .pocket)
        }
        // What it holds sits above the placement it decides on.
        #expect(
            ShortcutsRowOrder.pocketList.first
                == .shortcuts(.pocketCapacity)
        )
    }

    @Test("each capacity reads as its segment says it")
    func capacityNames() {
        LocalizationManager.shared.select("en")
        #expect(PocketGroup.capacityName(.one) == "One window")
        #expect(PocketGroup.capacityName(.several) == "Several windows")
    }

    /// The Pocket card draws Holds first, and no row of it greys
    /// (#2678).
    @Test("no Pocket row greys, and the Holds row is drawn")
    func nothingGreys() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "PocketGroup.swift"
            )
        )
        // The body draws Holds ahead of the keys (owner, #2678);
        // where the pocket sits is KiwiShelf's card.
        let body = try #require(source.range(of: "var body: some View"))
        let drawn = String(source[body.upperBound...])
        let holds = try #require(
            drawn.range(of: "\n            capacityRow\n")
        )
        let keys = try #require(
            drawn.range(of: "ShortcutsRowOrder.pocketAtRest")
        )
        #expect(holds.lowerBound < keys.lowerBound)
        #expect(!drawn.contains("edgeRow"))
        #expect(source.contains("$0.pocketCapacity = new"))
        // Every way a row could grey: none applies.
        for grey in [
            "GreyOut", "CrossReferenceRow", "onStateChange", ".disabled(",
            ".opacity(",
        ] {
            #expect(!source.contains(grey), "\(grey)")
        }
    }

    @Test("an edge reads as every edge row says it")
    func edgeNames() {
        LocalizationManager.shared.select("en")
        #expect(AppBarOptions.edgeName(.top) == "Top")
        #expect(AppBarOptions.edgeName(.right) == "Right")
    }
}
