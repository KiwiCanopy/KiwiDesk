import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Pocket card (#2680): its keys moved in from Size & float,
/// its placement rows, their grey and the pointer under it.
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
    }

    /// The pointer under the grey places its link (`CrossReferenceRow`
    /// ▸ the slot), and names the switch through its own key.
    @Test("the grey's pointer places its link")
    func proseHasTheSlot() {
        LocalizationManager.shared.select("en")
        #expect(
            PocketGroup.inertProse.contains(CrossReferenceRow.linkSlot)
        )
        #expect(
            PocketGroup.inertProse.contains(
                "Animate float, Pocket & maximize"
            )
        )
    }

    /// The two rows grey on the state-change toggle, the pointer is
    /// drawn outside that grey, and only while it holds.
    @Test("the placement rows grey on the toggle, the pointer outside")
    func greyIsWired() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "PocketGroup.swift"
            )
        )
        #expect(source.contains("!model.config.settings.animations"))
        #expect(source.contains(".onStateChange"))
        #expect(source.contains(".modifier(GreyOut(active: inert))"))
        #expect(source.contains("if inert {"))
        #expect(source.contains("destination: .looks"))
    }

    @Test("an edge reads as the bars' edge rows say it")
    func edgeNames() {
        LocalizationManager.shared.select("en")
        #expect(PocketGroup.edgeName(.top) == "Top")
        #expect(PocketGroup.edgeName(.right) == "Right")
    }
}
