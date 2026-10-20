import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile's tombstones after the "Shortcuts use" switch moved
/// the shared rows they name (#2460): each follows its row, so a
/// row the profile left out stays out there.
@Suite("A profile's tombstones follow a moved base row (#2460)")
struct KeyLayerOverrideFollowTests {
    private let main = KeyLayer.defaultName

    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, label: "")
    }

    private var moves: [String: [String: String]] {
        [main: ["control+option+f": "hyper+f"]]
    }

    @Test("a tombstone on the old chord takes the new one")
    func tombstoneMoves() {
        let over = KeyLayerOverride(removed: [main: ["control+option+f"]])
        #expect(over.following(moves).removed == [main: ["hyper+f"]])
    }

    @Test("a tombstone already on the new chord is not doubled")
    func tombstoneIsNotDoubled() {
        let over = KeyLayerOverride(
            removed: [main: ["control+option+f", "hyper+f"]]
        )
        #expect(over.following(moves).removed == [main: ["hyper+f"]])
    }

    @Test("an own row on the old chord leaves the moved row out")
    func ownRowLeavesItOut() {
        let over = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: main,
                    bindings: [row("control+option+f", "hs.x()")]
                )
            ]
        )
        let base = [
            KeyLayer(
                name: main,
                bindings: [row("hyper+f", "KiwiDesk.toggle_floating()")]
            )
        ]
        let followed = over.following(moves)
        #expect(followed.removed == [main: ["hyper+f"]])
        #expect(
            followed.resolved(onto: base).first?.bindings.map(\.lua)
                == ["hs.x()"]
        )
    }

    @Test("a layer left out whole and an unmoved layer are untouched")
    func otherLayersAreUntouched() {
        let over = KeyLayerOverride(
            removed: [
                main: ["control+option+f"],
                "work": ["control+option+w"],
            ],
            leftOut: ["work"]
        )
        let followed = over.following([
            "work": ["control+option+w": "hyper+w"]
        ])
        #expect(followed == over)
    }
}
