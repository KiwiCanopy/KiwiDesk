import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A cold boot runs `init.lua` before any screen is published, so
/// a pin by screen name waits for the first `.displaysChanged`
/// (#3631). The reporter's desk: an external main screen and the
/// built-in panel, Comms pinned to the built-in by name.
@Suite("Boot applies init.lua's screen pins (#3631)", .serialized)
@MainActor
struct BootSpacePinTests {
    private static let external = Display(
        id: DisplayID(3),
        name: "LG HDR 4K",
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)
    )
    private static let builtIn = Display(
        id: DisplayID(1),
        name: "Built-in Retina Display",
        frame: CGRect(x: 2560, y: 0, width: 1512, height: 982)
    )
    /// `app_rules` makes the file own the setup, as the report's
    /// does; a pin alone would leave a seeded `gui.json` owning it.
    private static let pinComms = """
        app_rules = { ["com.apple.mail"] = "Comms" }
        KiwiDesk.pin_space_to_display("Code", "LG HDR 4K")
        KiwiDesk.pin_space_to_display("Comms", "Built-in Retina Display")

        """

    private func makeCore(lua: String) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-3631-\(UUID().uuidString)"
                )
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try writeLua(lua, core)
        return core
    }

    private func writeLua(_ lua: String, _ core: KiwiCore) throws {
        try lua.write(to: core.configURL, atomically: true, encoding: .utf8)
    }

    private func spaces(_ core: KiwiCore, on display: Display) -> [SpaceID] {
        core.state.workspaces.spaces(on: display.id)
    }

    private func heldPins(_ core: KiwiCore) -> [SpaceID] {
        core.heldScreenCalls.compactMap(\.pinnedSpace)
    }

    private func dock(_ core: KiwiCore) {
        core.handle(.displaysChanged([Self.external, Self.builtIn]))
    }

    @Test("a pin by name loaded with no screen lands at the first report")
    func bootPinApplies() throws {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = try makeCore(lua: Self.pinComms)
        // After `makeTestCore`, which installs the host's main.
        PositionalDisplays.mainIDOverride = { Self.external.id }
        var log: [String] = []
        core.onLog = { log.append($0) }
        #expect(core.state.workspaces.allDisplays.isEmpty)
        core.loadConfig()
        #expect(core.spacePins.isEmpty)
        dock(core)
        #expect(spaces(core, on: Self.builtIn).contains("Comms"))
        #expect(!spaces(core, on: Self.external).contains("Comms"))
        #expect(core.spacePins["Comms"] == Self.builtIn.fingerprint)
        #expect(core.heldScreenCalls.isEmpty)
        #expect(!log.contains { $0.hasPrefix("heal:") })
    }

    @Test("a pin dropped from init.lua before the report never lands")
    func droppedPinNeverApplies() throws {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = try makeCore(lua: Self.pinComms)
        // After `makeTestCore`, which installs the host's main.
        PositionalDisplays.mainIDOverride = { Self.external.id }
        core.loadConfig()
        let code = """
            app_rules = { ["com.apple.mail"] = "Comms" }
            KiwiDesk.pin_space_to_display("Code", "LG HDR 4K")

            """
        try writeLua(code, core)
        core.loadConfig()
        #expect(heldPins(core) == ["Code"])
        dock(core)
        #expect(core.spacePins["Comms"] == nil)
        #expect(core.spacePins["Code"] == Self.external.fingerprint)
    }

    @Test("a Space dropped before the report takes its held pin with it")
    func droppedSpaceForgetsItsPin() throws {
        let core = try makeCore(lua: Self.pinComms)
        core.loadConfig()
        #expect(heldPins(core).contains("Comms"))
        core.forwardWindows(of: "Comms", to: "Code")
        #expect(!heldPins(core).contains("Comms"))
        dock(core)
        #expect(core.state.workspaces["Comms"] == nil)
    }

    @Test("with screens known, a name no screen matches still fails")
    func unmatchedNameFailsLive() throws {
        let core = try makeCore(lua: "")
        dock(core)
        let response = core.execute(
            "pin_space_to_display",
            args: [.string("Comms"), .string("No Such Screen")]
        )
        #expect(!response.isSuccess)
        #expect(core.heldScreenCalls.isEmpty)
    }
}
