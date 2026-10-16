import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A lens rename or delete (#2103 rulings 38, 39): a profile's
/// `lens_reach` mark moves with a rename and goes with a delete,
/// and the lens on follows an announced rename instead of turning
/// off.
@Suite("KiwiVision lens rename and delete", .serialized)
@MainActor
struct KiwiVisionLensRenameTests {
    @Test("a rename moves the mark, ignoring case")
    func renameMovesTheMark() {
        let reach = ["writing": false, "mail": true]
        #expect(
            VisionLens.reach(reach, renaming: "WRITING", to: "Draft")
                == ["draft": false, "mail": true]
        )
        #expect(
            VisionLens.reach(reach, renaming: "Chat", to: "Talk") == reach
        )
        #expect(VisionLens.reach(nil, renaming: "Writing", to: "D") == nil)
    }

    @Test("a delete clears the mark, an emptied map stored as none")
    func deleteClearsTheMark() {
        #expect(
            VisionLens.reach(
                ["writing": false, "mail": false],
                deleting: "Writing"
            )
                == ["mail": false]
        )
        #expect(
            VisionLens.reach(["writing": false], deleting: "writing") == nil
        )
        #expect(VisionLens.reach(nil, deleting: "Writing") == nil)
    }

    private func core() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-lens-rename-\(UUID())")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.eventLoop.ownKeyWindow = { nil }
        core.execute(
            "kiwivision.define_lens",
            args: [
                .object([
                    "name": .string("Writing"),
                    "apps": .array([.string("test.kiwi.notes")]),
                ])
            ]
        )
        core.execute("kiwivision.toggle", args: [.string("Writing")])
        return core
    }

    private func rename(_ core: KiwiCore, to name: String) {
        core.setAppWide(persisting: false) { settings in
            settings.visionLenses = settings.visionLenses.map {
                var lens = $0
                lens.name = name
                return lens
            }
        }
    }

    @Test("the lens on follows an announced rename")
    func activeFollowsTheRename() {
        let core = core()
        #expect(core.kiwiVisionActive == .lens("Writing"))
        core.noteLensRename(from: "writing", to: "Draft")
        rename(core, to: "Draft")
        #expect(core.kiwiVisionActive == .lens("Draft"))
        #expect(core.vision.renamedLens == nil)
    }

    @Test("an unannounced rename reads as a removal and turns it off")
    func unannouncedRenameTurnsOff() {
        let core = core()
        rename(core, to: "Draft")
        #expect(core.kiwiVisionActive == .off)
    }
}
