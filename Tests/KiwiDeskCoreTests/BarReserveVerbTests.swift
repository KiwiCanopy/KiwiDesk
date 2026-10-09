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

    /// The skip key compares the shelf's depth too, but no bar
    /// verb writes the shelf today, so that clause cannot red on
    /// its own (guard-prover, #1524). This watches the fact it
    /// leans on: every registered bar verb, read off its records,
    /// leaves `kiwishelf` alone — a bar verb that starts writing
    /// the shelf must then prove the depth clause.
    @Test("No bar verb writes the shelf")
    func barVerbsLeaveTheShelf() {
        let verbs =
            APIReference.spaceBarRecords.keys.map {
                "space_bar.\($0)"
            } + APIReference.appBarRecords.keys.map { "app_bar.\($0)" }
        #expect(verbs.count > 10)
        for verb in verbs.sorted() {
            for variant in 0..<2 {
                let core = makeTestCore()
                let shelf = core.tiler.settings.kiwishelf
                let response = core.execute(
                    verb,
                    args: Self.arguments(for: verb, variant: variant)
                )
                #expect(response.isSuccess, Comment(rawValue: verb))
                #expect(
                    core.tiler.settings.kiwishelf == shelf,
                    Comment(rawValue: "\(verb) wrote the shelf")
                )
            }
        }
    }

    /// Two values per argument in the record's own shape — the
    /// first and the last of a choice, both booleans, two
    /// numbers — so a write off the default is reached.
    private static func arguments(
        for verb: String,
        variant: Int
    ) -> [JSONValue] {
        let record = APIReference.entry(named: verb)?.record
        return (record?.arguments ?? []).map { argument in
            switch argument.kind {
            case .number, .integer:
                return .number(variant == 0 ? 1 : 9)
            case .boolean: return .bool(variant == 0)
            case .color:
                return .string(variant == 0 ? "#FFFFFF" : "#102030")
            case .choice(let choice):
                let values = choice.values
                return .string(
                    (variant == 0 ? values.first : values.last) ?? ""
                )
            default: return .string("probe")
            }
        }
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
