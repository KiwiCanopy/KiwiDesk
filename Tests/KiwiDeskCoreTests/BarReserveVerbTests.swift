import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.set_reserve` and `app_bar.set_reserve` (#1524):
/// both reach the stored style from the CLI and from Lua, and a
/// layout's App Bar refuses its own, since the reservation is
/// the bar's and never a layout's.
@Suite("Bar reserve verbs (#1524)", .serialized)
@MainActor
struct BarReserveVerbTests {
    @Test("set_reserve reaches the stored style over the CLI")
    func cliRoundTrip() {
        let core = makeTestCore()
        for bar in ["space_bar", "app_bar"] {
            #expect(
                core.execute("\(bar).set_reserve", args: [.bool(false)])
                    .isSuccess
            )
        }
        #expect(!core.tiler.settings.spaceBarStyle.reserve)
        #expect(!core.tiler.settings.appBarStyle.reserve)
        #expect(
            !core.execute("space_bar.set_reserve", args: [.string("no")])
                .isSuccess
        )
    }

    /// The honest refusal, not a retirement: no layout verb for
    /// it ever shipped.
    @Test("A layout's App Bar refuses its own reserve")
    func noLayoutReserve() {
        let core = makeTestCore()
        let before = core.tiler.settings
        for layout in ["monocle", "scroll"] {
            let verb = "\(layout).set_app_bar_reserve"
            #expect(APIReference.retirement(of: verb) == nil)
            let response = core.execute(verb, args: [.bool(false)])
            #expect(!response.isSuccess)
            #expect(
                response.error
                    == "the App Bar's reserve is global: "
                    + "app_bar.set_reserve"
            )
        }
        #expect(core.tiler.settings == before)
    }

    @Test("set_reserve reaches the stored style from Lua")
    func luaRoundTrip() throws {
        let core = makeTestCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        let result = lua.run(
            "space_bar.set_reserve(false)\napp_bar.set_reserve(false)"
        )
        guard case .success = result else {
            Issue.record("set_reserve run failed: \(result)")
            return
        }
        #expect(!core.tiler.settings.spaceBarStyle.reserve)
        #expect(!core.tiler.settings.appBarStyle.reserve)
    }
}
