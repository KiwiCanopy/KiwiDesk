import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-quit-cmd-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// The `quit.set_layout` dispatch seam (#197): storage,
/// validation, and the unknown-command fallthrough. The grid
/// math itself is pinned in `QuitGridLayoutTests`.
@Suite("Quit layout command (#197)")
@MainActor
struct QuitCommandTests {
    @Test("quit.set_layout stores a valid style")
    func storesValidStyle() {
        let core = makeCore()
        #expect(core.tiler.settings.quitLayout == .grid)
        #expect(
            core.execute(
                "quit.set_layout",
                args: [.string("grid")]
            ).isSuccess
        )
        #expect(core.tiler.settings.quitLayout == .grid)
    }

    @Test("an unknown style fails and lists accepted values")
    func rejectsUnknownStyle() {
        let core = makeCore()
        let response = core.execute(
            "quit.set_layout",
            args: [.string("stagger")]
        )
        #expect(!response.isSuccess)
        #expect(response.error == "expected grid")
        #expect(core.tiler.settings.quitLayout == .grid)
    }

    @Test("a missing argument fails")
    func rejectsMissingArgument() {
        let core = makeCore()
        #expect(
            !core.execute(
                "quit.set_layout",
                args: []
            ).isSuccess
        )
    }

    @Test("an unknown quit.* command fails")
    func rejectsUnknownCommand() {
        let core = makeCore()
        #expect(
            !core.execute(
                "quit.set_something",
                args: [.string("grid")]
            ).isSuccess
        )
    }

    @Test("quit.set_grid_target_depth stores a valid target")
    func storesTargetDepth() {
        let core = makeCore()
        #expect(
            core.tiler.settings.quitGridTargetDepth
                == QuitGridLayout.defaultTargetDepth
        )
        #expect(
            core.execute(
                "quit.set_grid_target_depth",
                args: [.number(8)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.quitGridTargetDepth == 8
        )
    }

    @Test("an out-of-range target fails and names the range")
    func rejectsOutOfRangeDepth() {
        let core = makeCore()
        for bad in [JSONValue.number(0), .number(21)] {
            let response = core.execute(
                "quit.set_grid_target_depth",
                args: [bad]
            )
            #expect(!response.isSuccess)
            #expect(response.error == "expected 1-20")
        }
        #expect(
            core.tiler.settings.quitGridTargetDepth
                == QuitGridLayout.defaultTargetDepth
        )
    }

    @Test("a huge finite target fails instead of trapping")
    func rejectsHugeDepth() {
        // Int(1e300) traps — the bounds check must run on the
        // Double, before any Int conversion (#58 lesson).
        let core = makeCore()
        let response = core.execute(
            "quit.set_grid_target_depth",
            args: [.number(1e300)]
        )
        #expect(!response.isSuccess)
        #expect(
            core.tiler.settings.quitGridTargetDepth
                == QuitGridLayout.defaultTargetDepth
        )
    }

    @Test("a non-numeric target fails")
    func rejectsNonNumericDepth() {
        let core = makeCore()
        #expect(
            !core.execute(
                "quit.set_grid_target_depth",
                args: [.string("deep")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "quit.set_grid_target_depth",
                args: []
            ).isSuccess
        )
    }
}
