import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The hint panel over an `init.lua` whose sequence the importer
/// could not read back (#1871): the snapshot lacks it, so the panel
/// draws the running tree, never nothing while the tap swallows
/// keys. `.serialized` as the Lua-owned panel suite is.
@Suite("Key sequence hint fallback", .serialized)
@MainActor
struct KeySequenceHintFallbackTests {
    @Test("an unread Lua sequence still draws its step")
    func unreadSequenceDraws() throws {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-seq-hint-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try """
        KiwiDesk.define_sequence("ctrl+alt+space", {
          h = { fn = KiwiDesk.toggle_float, name = "Left" },
        }, { name = "Leader" })
        """.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        let snapshot = try #require(core.liveKeybindingSnapshot())
        #expect(snapshot.keyLayers.first?.sequences.isEmpty == true)
        let controller = KeySequenceHintController(core: core)
        controller.follow(
            KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        )
        let (hint, _) = try #require(controller.hint())
        #expect(hint.title == "Leader")
        #expect(hint.endKeys.bindings.map(\.combo) == ["h"])
        controller.follow(nil)
    }
}
