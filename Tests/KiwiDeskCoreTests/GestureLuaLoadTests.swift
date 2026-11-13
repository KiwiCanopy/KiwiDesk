import Foundation
import Testing

@testable import KiwiDeskCore

/// A `gesture.bind` in `init.lua` makes the file the owner of the
/// setup, as `KiwiDesk.bind` does, so the binding reaches the
/// running gestures after a load and Adopt into the GUI keeps it
/// (#3297).
@Suite("Gesture bind from init.lua survives the load", .serialized)
@MainActor
struct GestureLuaLoadTests {
    private let bind = #"gesture.bind("tap5", "", "KiwiDesk.cycle_mode()")"#

    private func makeCore(lua: String, guiConfig: GuiConfig?) throws
        -> KiwiCore
    {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-gesture-lua-\(UUID().uuidString)"
                )
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        if let guiConfig { try core.guiConfigStore.save(guiConfig) }
        try lua.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        return core
    }

    private func tap5(_ core: KiwiCore) -> GestureAction? {
        core.mouse.gestures.resolved[GestureKey(.tap5)]
    }

    private var expected: GestureAction {
        .run(LuaAction(lua: "KiwiDesk.cycle_mode()"))
    }

    @Test("a desk gui.json owned hands itself to init.lua")
    func guiManagedKeeps() throws {
        let core = try makeCore(lua: "\(bind)\n", guiConfig: GuiConfig())
        core.loadConfig()
        #expect(!core.isGuiManaged)
        #expect(tap5(core) == expected)
    }

    @Test("a fresh desk seeds no gui.json over the binding")
    func freshDeskKeeps() throws {
        let core = try makeCore(lua: "\(bind)\n", guiConfig: nil)
        core.loadConfig()
        #expect(!core.guiConfigStore.exists)
        #expect(tap5(core) == expected)
    }

    @Test("adopting keeps the gesture base Lua set")
    func adoptKeeps() throws {
        let core = try makeCore(lua: "\(bind)\n", guiConfig: nil)
        core.loadConfig()

        try core.adoptConfigIntoGui { _ in }

        #expect(core.isGuiManaged)
        #expect(tap5(core) == expected)
        #expect(
            core.guiConfigStore.load()?.gesture[GestureKey(.tap5)]
                == .bound(expected)
        )
        let file = try String(
            contentsOf: core.configURL,
            encoding: .utf8
        )
        #expect(file.contains("-- \(bind)"))
    }
}
