import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `set_display_areas` and `set_display_area_name` (#3517): the
/// split is stored per screen, refused when it does not tile the
/// screen, and named only with a name no other area or screen has.
@Suite("Display area commands")
@MainActor
struct DisplayAreaCommandTests {
    private let wide = Display(
        id: DisplayID(900_001),
        name: "LG UltraWide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func core() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(wide)
        return core
    }

    private func split(_ core: KiwiCore) -> ScreenSplit? {
        core.tiler.settings.displayAreas
            .split(
                on: wide.fingerprint,
                order: core.liveScreenOrder,
                floors: .unfloored
            )
    }

    @Test func sizesSplitTheScreen() throws {
        let core = core()
        let reply = core.execute(
            "set_display_areas",
            args: [
                .string(wide.fingerprint), .string("side_by_side"),
                .number(2580), .number(860),
            ]
        )
        #expect(reply.isSuccess)
        let stored = try #require(split(core))
        #expect(stored.areas.map(\.w) == [2580, 860])
        #expect(stored.areas.map(\.x) == [0, 2580])
        #expect(stored.areas.map(\.id) == [0, 1])
    }

    @Test func rectsFromLuaSplitTheScreen() throws {
        let core = core()
        let reply = core.execute(
            "set_display_areas",
            args: [
                .number(1),
                .array([
                    .object([
                        "x": .number(0), "y": .number(0),
                        "w": .number(3440), "h": .number(720),
                    ]),
                    .object([
                        "x": .number(0), "y": .number(720),
                        "w": .number(3440), "h": .number(720),
                        "name": .string("Calls"),
                    ]),
                ]),
            ]
        )
        #expect(reply.isSuccess)
        let stored = try #require(split(core))
        #expect(stored.areas.map(\.h) == [720, 720])
        #expect(stored.areas[1].name == "Calls")
    }

    @Test func noSizesMakeTheScreenWhole() {
        let core = core()
        core.execute(
            "set_display_areas",
            args: [
                .string(wide.fingerprint), .string("stacked"),
                .number(720), .number(720),
            ]
        )
        #expect(split(core) != nil)
        let reply = core.execute(
            "set_display_areas",
            args: [.string(wide.fingerprint)]
        )
        #expect(reply.isSuccess)
        // Kept whole, so its next id outlives the merge (ruling 21).
        #expect(core.tiler.settings.displayAreas["1"]?.isWhole == true)
    }

    @Test func brokenSplitsAreRefused() {
        let core = core()
        for sizes in [[3000.0, 400], [1720, 1000], [3400, 40]] {
            let reply = core.execute(
                "set_display_areas",
                args: [.string(wide.fingerprint), .string("side_by_side")]
                    + sizes.map(JSONValue.number)
            )
            #expect(!reply.isSuccess, "\(sizes)")
        }
        #expect(split(core) == nil)
        let unknown = core.execute(
            "set_display_areas",
            args: [.string("Nowhere")]
        )
        #expect(!unknown.isSuccess)
    }

    @Test func areasAreNamedByKey() throws {
        let core = core()
        core.execute(
            "set_display_areas",
            args: [
                .string(wide.fingerprint), .string("side_by_side"),
                .number(1720), .number(1720),
            ]
        )
        let key = ScreenAreaKey(fingerprint: wide.fingerprint, areaID: 1)
        #expect(
            core.execute(
                "set_display_area_name",
                args: [.string(key.description), .string("Calls")]
            ).isSuccess
        )
        #expect(try #require(split(core)).areas[1].name == "Calls")
        for taken in ["Calls", "42", "LG UltraWide"] {
            let reply = core.execute(
                "set_display_area_name",
                args: [.string(wide.fingerprint), .string(taken)]
            )
            #expect(!reply.isSuccess, "\(taken)")
        }
        core.execute(
            "set_display_area_name",
            args: [.string(key.description), .string("")]
        )
        #expect(try #require(split(core)).areas[1].name == nil)
    }

    @Test func listMonitorsPrintsAreaKeys() throws {
        let core = core()
        core.execute(
            "set_display_areas",
            args: [
                .string(wide.fingerprint), .string("side_by_side"),
                .number(1720), .number(1720),
            ]
        )
        let reply = core.execute("list_monitors", args: [])
        guard case .array(let monitors)? = reply.data,
            case .object(let first)? = monitors.first,
            case .array(let areas)? = first["areas"]
        else {
            Issue.record("no areas in \(String(describing: reply.data))")
            return
        }
        let keys = areas.compactMap { entry -> String? in
            guard case .object(let fields) = entry else { return nil }
            return fields["key"]?.stringValue
        }
        #expect(keys == [wide.fingerprint, "\(wide.fingerprint)#1"])
    }

    @Test func splitSurvivesSettingsCoding() throws {
        var settings = TilingSettings()
        let split = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        )
        settings.displayAreas[number: 1] = ScreenShares(
            split,
            width: 3440,
            height: 1440
        )
        let data = try JSONEncoder().encode(settings)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"display_areas\""))
        let back = try JSONDecoder().decode(TilingSettings.self, from: data)
        #expect(back.displayAreas == settings.displayAreas)
        let empty = try JSONEncoder().encode(TilingSettings())
        let emptyJSON = try #require(String(data: empty, encoding: .utf8))
        #expect(!emptyJSON.contains("display_areas"))
    }

    @Test func remergedScreenKeepsItsNextID() throws {
        let core = core()
        let fp = JSONValue.string(wide.fingerprint)
        for args: [JSONValue] in [
            [fp, .string("side_by_side"), .number(1720), .number(1720)],
            [fp],
            [fp, .string("side_by_side"), .number(1720), .number(1720)],
        ] {
            #expect(core.execute("set_display_areas", args: args).isSuccess)
        }
        // The second split mints a fresh id rather than reusing 1.
        #expect(try #require(split(core)).areas.map(\.id) == [0, 2])
    }
}
