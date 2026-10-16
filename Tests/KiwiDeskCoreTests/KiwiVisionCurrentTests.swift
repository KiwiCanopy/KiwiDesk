import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwivision.current` (#2103, #1685 ▸ Ruling 2): what KiwiVision
/// draws, the plain settings as `gui.json` stores them, and every
/// live lens as its `define_lens` table with its refusal and
/// whether `gui.json` holds it as it is.
@Suite("KiwiVision current", .serialized)
@MainActor
struct KiwiVisionCurrentTests {
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-current-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        try core.guiConfigStore.save(GuiConfig())
        return core
    }

    private func run(
        _ core: KiwiCore,
        _ command: String,
        _ args: [JSONValue] = []
    ) {
        #expect(core.execute(command, args: args).isSuccess, "\(command)")
    }

    private func define(_ core: KiwiCore, _ lens: [String: JSONValue]) {
        run(core, "kiwivision.define_lens", [.object(lens)])
    }

    private func current(_ core: KiwiCore) -> [String: JSONValue] {
        let answer = core.execute("kiwivision.current")
        #expect(answer.isSuccess)
        guard case .object(let fields)? = answer.data else { return [:] }
        return fields
    }

    private typealias Row = [String: JSONValue]

    /// The answer's lens rows, by name.
    private func lenses(_ fields: Row) -> [String: Row] {
        guard case .array(let rows)? = fields["lenses"] else { return [:] }
        var out: [String: Row] = [:]
        for case .object(let row) in rows {
            out[row["name"]?.stringValue ?? ""] = row
        }
        return out
    }

    @Test("off names no lens and lists the plain settings")
    func offState() throws {
        let core = try makeCore()
        run(core, "kiwivision.set_dim", [.number(30)])
        run(core, "kiwivision.set_clear_app", [.bool(true)])
        let fields = current(core)
        #expect(fields["on"] == .bool(false))
        #expect(fields["lens"] == .null)
        guard case .object(let settings)? = fields["plain"] else {
            Issue.record("no settings")
            return
        }
        #expect(settings["dim"] == .number(30))
        #expect(settings["clear_app"] == .bool(true))
        #expect(settings["lenses"] == nil)
        #expect(fields["lenses"] == .array([]))
    }

    @Test("a lens on is named, and each lens is its table")
    func lensOn() throws {
        let core = try makeCore()
        define(
            core,
            [
                "name": .string("Writing"),
                "apps": .array([.string("test.kiwi.notes")]),
                "dim": .number(80),
            ]
        )
        define(core, ["name": .string("Calls")])
        run(core, "kiwivision.toggle", [.string("writing")])
        let fields = current(core)
        #expect(fields["on"] == .bool(true))
        #expect(fields["lens"] == .string("Writing"))
        let rows = lenses(fields)
        let writing = rows["Writing"] ?? [:]
        #expect(writing["apps"] == .array([.string("test.kiwi.notes")]))
        #expect(writing["dim"] == .number(80))
        #expect(writing["refusal"] == nil)
        #expect(writing["saved"] == .bool(false))
        #expect(
            rows["Calls"]?["refusal"]
                == .object(["reason": .string("no_apps")])
        )
    }

    @Test("plain KiwiVision is on with no lens")
    func plainOn() throws {
        let core = try makeCore()
        run(core, "kiwivision.toggle")
        let fields = current(core)
        #expect(fields["on"] == .bool(true))
        #expect(fields["lens"] == .null)
    }

    @Test("a lens the live profile leaves out names that profile")
    func outOfReach() throws {
        let core = try makeCore()
        define(
            core,
            [
                "name": .string("Writing"),
                "apps": .array([.string("test.kiwi.notes")]),
            ]
        )
        try core.profiles.write(
            Profile(
                name: "Studio",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: TilingSettings(),
                lensReach: ["writing": false]
            )
        )
        run(core, "load_profile", [.string("Studio")])
        #expect(
            lenses(current(core))["Writing"]?["refusal"]
                == .object([
                    "reason": .string("out_of_reach"),
                    "profile": .string("Studio"),
                ])
        )
    }

    @Test("a lens gui.json holds as it is reads saved")
    func savedLens() throws {
        let core = try makeCore()
        var lens = VisionLens(name: "Writing")
        lens.apps = ["test.kiwi.notes"]
        core.setAppWide(persisting: true) { $0.visionLenses = [lens] }
        #expect(lenses(current(core))["Writing"]?["saved"] == .bool(true))
        define(
            core,
            [
                "name": .string("Writing"),
                "apps": .array([.string("test.kiwi.other")]),
            ]
        )
        #expect(
            lenses(current(core))["Writing"]?["saved"] == .bool(false)
        )
    }

    @Test("the table keys are the lens coding's keys")
    func tableKeysAreTheCoding() throws {
        var lens = VisionLens(name: "Writing")
        lens.apps = ["a"]
        lens.titles = ["a": ["Docs"]]
        lens.reminder = "Back"
        lens.overrides = VisionLens.Overrides(
            dim: 50,
            blur: true,
            appearance: .dark,
            clearWallpaper: true,
            clearApp: true
        )
        let data = try JSONEncoder().encode(lens)
        let object = try JSONSerialization.jsonObject(with: data)
        let keys = (object as? [String: Any])?.keys.sorted() ?? []
        #expect(!keys.isEmpty)
        #expect(VisionLens.tableKeys.sorted() == keys)
    }
}
