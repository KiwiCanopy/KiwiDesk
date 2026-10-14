import Foundation
import Testing

@testable import KiwiDeskCore

/// `keep_settings` (#1685 ▸ Ruling 4): the leaves a report named
/// land as they are live now, through the one live-profile door,
/// a follower's look leaves in the shared look.
@Suite("Keep settings", .serialized)
@MainActor
struct KeepSettingsTests {
    private func keep(_ core: KiwiCore, _ ids: [String]) -> CommandResponse {
        core.execute(
            KiwiCore.keepSettingsCommand,
            args: ids.map(JSONValue.string)
        )
    }

    private func members(_ data: JSONValue?, _ key: String) -> [String] {
        guard case .object(let fields)? = data,
            case .array(let items)? = fields[key]
        else { return [] }
        return items.compactMap { item in
            guard case .object(let leaf) = item else { return nil }
            return leaf["id"]?.stringValue
        }
    }

    @Test("an own profile keeps a leaf and a layout, told to a draft")
    func ownProfileKeeps() throws {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        var told: [Bool] = []
        var draft = GuiConfig()
        core.onLiveProfileWritten = { edit, persisted in
            told.append(persisted)
            draft.apply(edit)
        }
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        let mode = KeepFixture.report(
            core,
            "set_mode",
            [.string("1"), .string("monocle")]
        )
        let ids =
            (width.changes?.touched ?? [])
            + (mode.changes?.touched ?? [])
        let response = keep(core, ids.map(\.id))
        #expect(response.isSuccess)
        #expect(told == [true])
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.settings.borderStyle.width == 9)
        #expect(stored.spaceModes["1"] == .monocle)
        #expect(draft.settings.borderStyle.width == 9)
        #expect(draft.spaceModes["1"] == .monocle)
        #expect(Set(members(response.data, "kept")) == Set(ids.map(\.id)))
    }

    @Test("a follower's look leaf lands in the shared look")
    func followerLandsSharedLook() throws {
        let core = try KeepFixture.core()
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        let ids = (width.changes?.touched ?? []).map(\.id)
        let response = keep(core, ids)
        #expect(response.isSuccess)
        let shared = core.guiConfigStore.load()?.look?.style["border.width"]
        #expect(shared == .number(9))
        guard case .object(let fields)? = response.data,
            case .array(let followers)? = fields["followers"]
        else {
            Issue.record("no followers named")
            return
        }
        #expect(followers.contains(.string("Work")))
    }

    @Test("a keep writes the value live now, not the one reported")
    func keepsTheLiveValue() throws {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        _ = core.execute("border.set_width", args: [.number(3)])
        _ = keep(core, (width.changes?.touched ?? []).map(\.id))
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.settings.borderStyle.width == 3)
    }

    @Test("a Lua-owned config refuses every leaf and writes nothing")
    func luaOwnedRefuses() throws {
        let core = try KeepFixture.core(gui: false)
        var told = 0
        core.onLiveProfileWritten = { _, _ in told += 1 }
        let response = keep(core, ["/settings/border/width"])
        #expect(response.isSuccess)
        #expect(members(response.data, "kept").isEmpty)
        #expect(
            members(response.data, "not_keepable")
                == ["/settings/border/width"]
        )
        #expect(told == 0)
    }

    @Test("ids that are not leaf pointers are refused")
    func badIdsFail() throws {
        let core = try KeepFixture.core()
        #expect(!core.execute("keep_settings", args: []).isSuccess)
        #expect(!keep(core, ["border.width"]).isSuccess)
        #expect(
            !core.execute("keep_settings", args: [.number(1)]).isSuccess
        )
    }
}
