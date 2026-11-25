import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A screen change that composes the built-in Standard announces
/// it, structure only, and nothing else does (#3646).
@Suite("Standard fallback announce (#3646)", .serialized)
@MainActor
struct StandardFallbackAnnounceTests {
    private let builtIn = Display(
        id: DisplayID(1),
        name: "BUILTIN",
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
    )
    private let external = Display(
        id: DisplayID(2),
        name: "EXTERNAL",
        frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440)
    )
    private let other = Display(
        id: DisplayID(3),
        name: "OTHER",
        frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    )

    /// A core whose config the GUI manages, with every announce
    /// recorded in `heard`.
    private func makeCore(
        guiManaged: Bool = true,
        heard: Heard
    ) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-3646-\(UUID().uuidString)"
                )
        )
        if guiManaged {
            try core.guiConfigStore.save(GuiConfig())
            #expect(core.isGuiManaged)
        }
        core.onStandardFallback = { heard.counts.append($0.screenCount) }
        return core
    }

    @Test("the first screen report with no profile announces")
    func firstReportAnnounces() throws {
        let heard = Heard()
        let core = try makeCore(heard: heard)
        core.handle(.displaysChanged([builtIn]))
        #expect(heard.counts == [1])
    }

    @Test("a settled count change announces its count")
    func settledChangeAnnounces() throws {
        let heard = Heard()
        let core = try makeCore(heard: heard)
        core.handle(.displaysChanged([builtIn]))
        core.execute("save_profile", args: [.string("solo")])
        heard.counts = []
        core.handle(.displaysChanged([builtIn, external]))
        #expect(heard.counts == [2])
    }

    @Test("a same-count re-report announces nothing")
    func reReportIsQuiet() throws {
        let heard = Heard()
        let core = try makeCore(heard: heard)
        core.handle(.displaysChanged([builtIn]))
        core.handle(.displaysChanged([builtIn]))
        #expect(heard.counts == [1])
    }

    @Test("the Starter recomposed for a new count announces")
    func starterRecomposeAnnounces() throws {
        let heard = Heard()
        let core = try makeCore(heard: heard)
        core.handle(.displaysChanged([builtIn]))
        core.seedFirstRunStarterProfile()
        #expect(core.isOnStarterBaseline)
        heard.counts = []
        core.handle(.displaysChanged([builtIn, external]))
        #expect(core.profiles.currentStandard == StarterSetup.name)
        #expect(heard.counts == [2])
    }

    @Test("a saved profile for the count announces nothing")
    func savedProfileIsQuiet() throws {
        let heard = Heard()
        let core = try makeCore(heard: heard)
        core.handle(.displaysChanged([builtIn]))
        core.execute("save_profile", args: [.string("solo")])
        core.handle(.displaysChanged([builtIn, external]))
        core.execute("save_profile", args: [.string("pair")])
        heard.counts = []
        core.handle(.displaysChanged([builtIn]))
        #expect(core.profiles.currentName == "solo")
        #expect(heard.counts.isEmpty)
    }

    @Test("the count's default profile announces nothing")
    func countDefaultIsQuiet() throws {
        let heard = Heard()
        let core = try makeCore(heard: heard)
        core.handle(.displaysChanged([builtIn, external]))
        core.execute("save_profile", args: [.string("pair")])
        core.handle(.displaysChanged([builtIn]))
        heard.counts = []
        core.handle(.displaysChanged([builtIn, other]))
        #expect(core.profiles.currentName == "pair")
        #expect(heard.counts.isEmpty)
    }

    @Test("a re-choice after a delete announces nothing")
    func deleteIsQuiet() throws {
        let heard = Heard()
        let core = try makeCore(heard: heard)
        core.handle(.displaysChanged([builtIn]))
        core.execute("save_profile", args: [.string("solo")])
        heard.counts = []
        core.execute("delete_profile", args: [.string("solo")])
        #expect(core.profiles.currentName == nil)
        #expect(heard.counts.isEmpty)
    }

    @Test("a config the GUI does not manage announces nothing")
    func luaOwnedIsQuiet() throws {
        let heard = Heard()
        let core = try makeCore(guiManaged: false, heard: heard)
        core.handle(.displaysChanged([builtIn]))
        #expect(heard.counts.isEmpty)
    }
}

@MainActor
private final class Heard {
    var counts: [Int] = []
}
