import Foundation
import Testing

@testable import KiwiDeskCore

/// Where the pocket sits is KiwiShelf's (#2678): `pocket_edge` and
/// `pocket_position` decode absent as bottom and 82, clamp, and are
/// set by `kiwishelf.set_pocket_*`.
@Suite("KiwiShelf pocket placement (#2678)")
@MainActor
struct KiwiShelfPocketPlacementTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-pocket-\(UUID().uuidString)")
        )
    }

    @Test("edge and position decode absent as bottom, 82")
    func storedShape() throws {
        let absent = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(absent.pocketEdge == .bottom)
        #expect(absent.pocketPosition == 82)
        let set = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(
                #"{"pocket_edge":"left","pocket_position":140}"#.utf8
            )
        )
        #expect(set.pocketEdge == .left)
        #expect(set.pocketPosition == 100)
        let encoded =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(KiwiShelf())
            ) as? [String: Any]
        #expect(encoded?["pocket_edge"] as? String == "bottom")
        #expect(encoded?["pocket_position"] as? Double == 82)
    }

    @Test("the Lua verbs set them and refuse a bad value")
    func verbs() {
        let core = makeCore()
        let top = core.execute(
            "kiwishelf.set_pocket_edge",
            args: [.string("top")]
        )
        #expect(top.isSuccess)
        #expect(core.tiler.settings.kiwishelf.pocketEdge == .top)
        let middle = core.execute(
            "kiwishelf.set_pocket_edge",
            args: [.string("middle")]
        )
        #expect(!middle.isSuccess)
        let thirty = core.execute(
            "kiwishelf.set_pocket_position",
            args: [.number(30)]
        )
        #expect(thirty.isSuccess)
        #expect(core.tiler.settings.kiwishelf.pocketPosition == 30)
        let below = core.execute(
            "kiwishelf.set_pocket_position",
            args: [.number(-5)]
        )
        #expect(below.isSuccess)
        #expect(core.tiler.settings.kiwishelf.pocketPosition == 0)
        let word = core.execute(
            "kiwishelf.set_pocket_position",
            args: [.string("x")]
        )
        #expect(!word.isSuccess)
    }

    @Test("the retired pocket verbs name their replacements")
    func retiredVerbs() {
        #expect(
            APIReference.retired["pocket.set_edge"]
                == .some("kiwishelf.set_pocket_edge")
        )
        #expect(
            APIReference.retired["pocket.set_position"]
                == .some("kiwishelf.set_pocket_position")
        )
    }
}
