import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Cores for the keep suites (#1685): GUI-managed or Lua-owned,
/// with a profile that follows the shared look or keeps its own.
/// Per-suite helpers by convention; this one file is shared by the
/// keep suites only because they split at the size ceiling — the
/// app rule suites keep through the same door.
@MainActor
enum KeepFixture {
    /// A core on one 100x100 screen. With `gui`, `gui.json` exists
    /// and the shared look is crossed from "Work", which follows it.
    static func core(gui: Bool = true) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-keep-\(UUID().uuidString)")
        )
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        guard gui else { return core }
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Work"))
        core.prepareSharedLook()
        load("Work", core)
        #expect(core.sharedLook != nil)
        return core
    }

    /// A profile declaring Space 1, with its own look unless told.
    static func profile(
        _ name: String,
        look: LookReference? = .own
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: ["1"],
            spaceModes: ["1": .bsp],
            settings: TilingSettings(),
            look: look
        )
    }

    static func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)]).isSuccess
        )
    }

    /// `command` asked over the socket with a change report.
    static func report(
        _ core: KiwiCore,
        _ command: String,
        _ args: [JSONValue] = []
    ) -> CommandResponse {
        core.answer(.reporting(command, args: args))
    }

    /// The touched leaf whose id starts with `prefix`.
    static func leaf(
        _ response: CommandResponse,
        _ prefix: String
    ) -> TouchedLeaf? {
        response.changes?.touched.first { $0.id.hasPrefix(prefix) }
    }
}
