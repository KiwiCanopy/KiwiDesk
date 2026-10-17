import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwihub.show(side)` (#2265): one verb opens KiwiHub on a side,
/// from Lua and over the dispatcher alike, and refuses a side it
/// does not know with the cases read off `KiwiHubSide`.
@Suite("kiwihub.show verb", .serialized)
@MainActor
struct KiwiHubShowVerbTests {
    @Test(
        "each side reaches the UI hook from Lua",
        arguments: KiwiHubSide.allCases
    )
    func luaOpensTheSide(side: KiwiHubSide) throws {
        let core = makeTestCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        var opened: [KiwiHubSide] = []
        core.uiBridge.onKiwihubShow = { opened.append($0) }
        guard case .success = lua.run(side.lua) else {
            Issue.record("\(side.lua) failed")
            return
        }
        #expect(opened == [side])
    }

    @Test("the dispatcher reaches it, so the CLI does too")
    func dispatchOpensTheSide() {
        let core = makeTestCore()
        var opened: [KiwiHubSide] = []
        core.uiBridge.onKiwihubShow = { opened.append($0) }
        let response = core.execute(
            "kiwihub.show",
            args: [.string("view")]
        )
        #expect(response.error == nil)
        #expect(opened == [.view])
    }

    @Test("an unknown or missing side is refused, the hook untouched")
    func unknownSideRefuses() {
        let core = makeTestCore()
        var opened = 0
        core.uiBridge.onKiwihubShow = { _ in opened += 1 }
        for args: [JSONValue] in [[.string("apps")], []] {
            let response = core.execute("kiwihub.show", args: args)
            #expect(
                response.error
                    == CommandResponse.expected(KiwiHubSide.self).error
            )
        }
        #expect(opened == 0)
    }

    @Test("the seed opens each side through the verb")
    func seedRunsTheVerb() {
        let seed = [
            DefaultKeybindings.jumpToWindowRow(),
            DefaultKeybindings.showShortcutsRow(),
            DefaultKeybindings.layoutPickerRow(),
        ].map(\.lua)
        #expect(seed == KiwiHubSide.allCases.map(\.lua))
    }
}
