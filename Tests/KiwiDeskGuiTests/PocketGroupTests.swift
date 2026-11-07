import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Pocket card (#2680): its keys moved in from Size & float,
/// and its rows, none greyed; when it shows is KiwiShelf's (#2978).
@Suite("Pocket card")
@MainActor
struct PocketGroupTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("the keys left Size & float for the Pocket card")
    func keysMoved() {
        let pocketKeys: [SettingKey] = [
            .shortcuts(.pocket), .shortcuts(.pocketWindow),
            .shortcuts(.pocketList),
        ]
        #expect(ShortcutsRowOrder.pocketAtRest == pocketKeys)
        for key in pocketKeys {
            #expect(
                !ShortcutsRowOrder.sizeAndFloatAtRest.contains(key)
            )
            #expect(key.placement.container == .pocket)
        }
    }

    /// Every key the census places in the card sits in exactly one
    /// of its three lists, and the card mounts the per-app rows
    /// (#2612).
    @Test("the card's lists partition its census keys")
    func listsPartitionTheCard() throws {
        let lists =
            ShortcutsRowOrder.pocketAtRest + ShortcutsRowOrder.pocketApps
        let placed = SettingKey.allCases.filter {
            $0.placement.area == .shortcuts
                && $0.placement.container == .pocket
        }
        #expect(Set(lists) == Set(placed))
        #expect(lists.count == Set(lists).count)
        #expect(ShortcutsRowOrder.pocketApps.contains(.shortcuts(.pocketApps)))
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "PocketGroup.swift"
            )
        )
        #expect(source.contains("PocketAppRows(model: model"))
    }

    /// No row of the Pocket card greys (#2678), and Holds retired
    /// for KiwiShelf's Show (#2978).
    @Test("no Pocket row greys, and no Holds row is drawn")
    func nothingGreys() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "PocketGroup.swift"
            )
        )
        // The body walks the keys; when the pocket shows and where it
        // sits are KiwiShelf's card (#2978).
        let body = try #require(source.range(of: "var body: some View"))
        let drawn = String(source[body.upperBound...])
        #expect(drawn.contains("ShortcutsRowOrder.pocketAtRest"))
        #expect(!drawn.contains("capacityRow"))
        #expect(!drawn.contains("edgeRow"))
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
