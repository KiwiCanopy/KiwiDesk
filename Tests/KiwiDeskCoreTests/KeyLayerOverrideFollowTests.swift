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

    private let floating = "KiwiDesk.toggle_floating()"

    private var moves: [String: [String: KeyBinding]] {
        [main: ["control+option+f": row("hyper+f", floating)]]
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
                bindings: [row("hyper+f", floating)]
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
            "work": ["control+option+w": row("hyper+w", "w()")]
        ])
        #expect(followed == over)
    }

    /// The mirror case: the profile's own row already held the new
    /// chord, which would replace the moved row there; the row
    /// stays on its old chord as the profile's own.
    @Test("an own row on the new chord keeps the moved row on the old")
    func ownRowOnTheNewChordKeepsTheRow() {
        let over = KeyLayerOverride(
            layers: [
                KeyLayer(name: main, bindings: [row("hyper+f", "hs.x()")])
            ]
        )
        let base = [
            KeyLayer(name: main, bindings: [row("hyper+f", floating)])
        ]
        let followed = over.following(moves)
        #expect(followed.removed.isEmpty)
        let resolved =
            followed.resolved(onto: base).first?.bindings ?? []
        #expect(Set(resolved.map(\.lua)) == ["hs.x()", floating])
        #expect(
            resolved.first { $0.lua == floating }?.combo
                == "control+option+f"
        )
    }

    /// The draft and the files may each take the switch once more
    /// before a Save lands; a second move must move nothing.
    @Test("moving onto the base the rows are on moves nothing")
    func secondMoveIsInert() {
        let layer = KeyLayer(
            name: main,
            bindings: [row("control+option+f", floating)]
        )
        let first = ShortcutBaseSwitch.move(
            layer,
            onto: .hyper,
            liveSpaces: []
        ) { _ in false }
        let second = ShortcutBaseSwitch.move(
            first.layer,
            onto: .hyper,
            liveSpaces: []
        ) { _ in false }
        #expect(first.moves.count == 1)
        #expect(second.moves.isEmpty)
        #expect(second.layer == first.layer)
    }
}
