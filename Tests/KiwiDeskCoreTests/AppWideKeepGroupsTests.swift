import Foundation
import Testing

@testable import KiwiDeskCore

/// The keep document's `app_wide` root names each value by its
/// `gui.json` group and key (#1685): every stored member of
/// `AppWideSettings` reaches its group — one leaf, or one per field
/// for KiwiHub's keys (#2600) — so a member added without its group
/// reds the count.
@Suite("App-wide keep groups")
struct AppWideKeepGroupsTests {
    private func leaves(_ value: JSONValue) -> [[String]] {
        KeepPointer.diff(.object([:]), value)
    }

    @Test("every member is one leaf of its gui.json group")
    func everyMemberIsALeaf() {
        var settings = AppWideSettings()
        // KiwiHub's keys are one member and a leaf per key (#2600),
        // each present only once set.
        for key in KiwiHubKey.allCases {
            settings.kiwiHubKeys[key] = "control+n"
        }
        let members = Mirror(reflecting: settings).children.count
        #expect(members > 0)
        #expect(
            leaves(settings.groupsJSON).count
                == members - 1 + KiwiHubKey.allCases.count
        )
    }

    @Test("a member is named by its stored key")
    func storedKeys() {
        var settings = AppWideSettings()
        let before = settings.groupsJSON
        settings.refusalSound.toggle()
        #expect(
            KeepPointer.diff(before, settings.groupsJSON)
                == [["refusal", "sound"]]
        )
    }
}
