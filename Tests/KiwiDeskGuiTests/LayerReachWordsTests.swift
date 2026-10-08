import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The words a layer's delete and rename say (#2022): who else
/// has the layer, named while there are two and counted past that,
/// and "every profile" only when that is all of them.
@Suite("Layer reach words (#2022)", .serialized)
@MainActor
struct LayerReachWordsTests {
    private let names = ["Desk", "Laptop", "Travel", "Lab"]

    private func reading(_ users: Set<String>) -> RuleReachReading {
        RuleReachReading(
            editing: "Desk",
            loaded: "Desk",
            profiles: names,
            unreadable: [],
            shared: false,
            hasShared: false,
            users: users,
            own: [:],
            ownIsShared: [],
            leftOut: []
        )
    }

    @Test("the delete message names who else has the layer")
    func deleteMessage() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let first =
            "This removes its shortcuts and every shortcut that "
            + "switches to it, 3 in all."
        #expect(LayerReachWords.deleteMessage(3, reading(["Desk"])) == first)
        #expect(
            LayerReachWords.deleteMessage(
                3,
                reading(["Desk", "Laptop", "Travel"])
            ) == first + " It's also in Laptop and Travel."
        )
        #expect(
            LayerReachWords.deleteMessage(3, reading(Set(names)))
                == first + " Every profile has this layer."
        )
    }

    @Test("the everywhere button climbs the removal ladder")
    func everywhereLadder() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            LayerReachWords.deleteEverywhere(reading(Set(names)))
                == "Delete from every profile"
        )
        #expect(
            LayerReachWords.deleteEverywhere(reading(["Desk", "Laptop"]))
                == "Delete from Desk and Laptop"
        )
        #expect(
            LayerReachWords.deleteEverywhere(
                reading(["Desk", "Laptop", "Travel"])
            ) == "Delete from every profile using it (3)"
        )
        #expect(
            LayerReachWords.deleteHere(reading(["Desk", "Laptop"]))
                == "Delete from Desk"
        )
    }

    @Test("the rename says where it reaches, and nothing for one")
    func renameReach() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(LayerReachWords.renameReach(reading(["Desk"])) == nil)
        #expect(
            LayerReachWords.renameReach(reading(["Desk", "Laptop"]))
                == "Renames it in Desk and Laptop."
        )
        #expect(
            LayerReachWords.renameReach(reading(Set(names)))
                == "Renames it in every profile."
        )
    }

    @Test("the edited profile, loaded, is marked both")
    func markBoth() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            RuleReachWords.mark("Desk", reading(["Desk"]))
                == "this profile, loaded"
        )
        #expect(RuleReachWords.mark("Laptop", reading(["Desk"])) == nil)
    }

    @Test("a greyed All profiles says why in its caption")
    func greyedAllCaption() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        var row = reading(["Desk"])
        row.layerShared = false
        #expect(
            RuleReachWords.allCaption(row)
                == "Only some profiles have this layer. To share the "
                + "row, share the layer first."
        )
        row.layerShared = true
        #expect(
            RuleReachWords.allCaption(row)
                == "Includes profiles you create later."
        )
    }
}
