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

    /// The plate shows on every window drag in both modes (#2678),
    /// so Edge and Position always act: no grey, no pointer at the
    /// animation switch.
    @Test("no Pocket row greys, and the Holds row is drawn")
    func nothingGreys() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "PocketGroup.swift"
            )
        )
        #expect(source.contains("capacityRow"))
        #expect(source.contains("selection: pocket.capacity"))
        #expect(!source.contains("GreyOut"))
        #expect(!source.contains("CrossReferenceRow"))
        #expect(!source.contains("onStateChange"))
    }

    @Test("an edge reads as every edge row says it")
    func edgeNames() {
        LocalizationManager.shared.select("en")
        #expect(AppBarOptions.edgeName(.top) == "Top")
        #expect(AppBarOptions.edgeName(.right) == "Right")
    }
}
