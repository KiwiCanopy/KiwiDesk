import Foundation
import Testing

@testable import KiwiDeskCore

/// `get_config_status` and the keep's newer-format refusal (#2490):
/// what a CLI or MCP caller reads before it writes, and what it is
/// told when a write is refused because a newer build wrote the
/// file.
@Suite("Config status (#2490)", .serialized)
@MainActor
struct ConfigStatusTests {
    private func status(_ core: KiwiCore) throws -> [String: JSONValue] {
        let response = core.execute(KiwiCore.configStatusCommand, args: [])
        #expect(response.isSuccess)
        guard case .object(let fields)? = response.data else {
            Issue.record("no object in \(String(describing: response.data))")
            return [:]
        }
        return fields
    }

    private func issues(_ fields: [String: JSONValue]) -> [[String: JSONValue]]
    {
        guard case .array(let items)? = fields["issues"] else { return [] }
        return items.compactMap {
            guard case .object(let issue) = $0 else { return nil }
            return issue
        }
    }

    @Test("each issue is named with its own fields")
    func issuesAreStructured() throws {
        let core = makeTestCore()
        core.configIssues = [
            ConfigIssue(source: "gui.json", kind: .newerFormat(.guiConfig)),
            ConfigIssue(
                source: "Work.json",
                kind: .profileBroken(.newerFormat),
                profileName: "Work"
            ),
            ConfigIssue(source: "init.lua", kind: .luaError("boom")),
        ]
        let listed = issues(try status(core))
        #expect(listed.count == 3)
        #expect(listed[0]["kind"] == .string("newer_format"))
        #expect(listed[0]["file"] == .string("gui.json"))
        #expect(listed[0]["source"] == .string("gui.json"))
        #expect(listed[1]["kind"] == .string("profile_broken"))
        #expect(listed[1]["cause"] == .string("newer_format"))
        #expect(listed[1]["profile"] == .string("Work"))
        #expect(listed[2]["kind"] == .string("lua_error"))
        #expect(listed[2]["message"] == .string("boom"))
    }

    @Test("an unfollowed sync folder reads off")
    func syncOff() throws {
        let core = makeTestCore()
        guard case .object(let sync)? = try status(core)["sync"] else {
            Issue.record("no sync object")
            return
        }
        #expect(sync["status"] == .string("off"))
        #expect(sync["folder"] == .null)
    }

    @Test("the sync status carries the file a newer build wrote")
    func syncNamesTheNewerFile() throws {
        let core = makeTestCore()
        core.sync.status = .newerHere(
            NewerFormatOnDisk(artifact: .guiConfig, format: 999)
        )
        guard case .object(let sync)? = try status(core)["sync"] else {
            Issue.record("no sync object")
            return
        }
        #expect(sync["status"] == .string("newer_here"))
        #expect(sync["file"] == .string("gui.json"))
    }

    @Test("a keep into a newer build's profile file says so")
    func keepNamesTheLatch() throws {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        let file = try core.profiles.fileURL(name: "Odd")
        var root = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: file))
                as? [String: Any]
        )
        root["format"] = Profile.currentFormat + 1
        try JSONSerialization.data(withJSONObject: root).write(to: file)

        let response = core.execute(
            KiwiCore.keepSettingsCommand,
            args: (width.changes?.touched ?? []).map { .string($0.id) }
        )
        #expect(response.isSuccess)
        guard case .object(let fields)? = response.data,
            case .array(let refused)? = fields["not_keepable"],
            case .object(let leaf)? = refused.first
        else {
            Issue.record("no refusal in \(String(describing: response.data))")
            return
        }
        #expect(leaf["id"] == .string("/settings/border/width"))
        #expect(
            leaf["not_keepable"] == .string("newer_format"),
            "\(fields)"
        )
    }
}
