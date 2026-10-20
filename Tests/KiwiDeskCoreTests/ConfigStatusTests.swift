import Foundation
import Testing

@testable import KiwiDeskCore

/// `get_config_status` (#2490): the Config Issues and the sync status
/// a CLI or MCP caller reads before it writes. The spellings are a
/// machine contract, so every case is pinned here.
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

    private func issues(_ core: KiwiCore) throws -> [[String: JSONValue]] {
        guard case .array(let items)? = try status(core)["issues"] else {
            return []
        }
        return items.compactMap {
            guard case .object(let issue) = $0 else { return nil }
            return issue
        }
    }

    private func sync(_ core: KiwiCore) throws -> [String: JSONValue] {
        guard case .object(let fields)? = try status(core)["sync"] else {
            Issue.record("no sync object")
            return [:]
        }
        return fields
    }

    @Test("every issue kind is named with its own fields")
    func everyKindIsSpelled() throws {
        let core = makeTestCore()
        let cases: [(ConfigIssue.Kind, [String: JSONValue])] = [
            (.luaVMUnavailable, ["kind": .string("lua_vm_unavailable")]),
            (
                .luaError("boom"),
                [
                    "kind": .string("lua_error"), "message": .string("boom"),
                ]
            ),
            (.guiConfigUnreadable, ["kind": .string("gui_config_unreadable")]),
            (.newerFormat(.guiConfig), ["kind": .string("newer_format")]),
            (
                .unknownCall(name: "fcus", suggestion: "focus"),
                [
                    "kind": .string("unknown_call"), "name": .string("fcus"),
                    "suggestion": .string("focus"),
                ]
            ),
            (
                .retiredCall(name: "old", replacement: nil),
                [
                    "kind": .string("retired_call"), "name": .string("old"),
                    "replacement": .null,
                ]
            ),
            (
                .missingFontFamily(name: "Mono"),
                [
                    "kind": .string("missing_font_family"),
                    "name": .string("Mono"),
                ]
            ),
        ]
        core.configIssues = cases.map {
            ConfigIssue(source: "init.lua", kind: $0.0)
        }
        let listed = try issues(core)
        try #require(listed.count == cases.count)
        for (issue, (_, expected)) in zip(listed, cases) {
            var expected = expected
            expected["source"] = .string("init.lua")
            #expect(issue == expected)
        }
    }

    @Test("every profile cause is spelled, with the profile named")
    func everyCauseIsSpelled() throws {
        let core = makeTestCore()
        let causes: [(ProfileBrokenCause, String)] = [
            (.malformedJSON, "malformed_json"),
            (.unexpectedShape, "unexpected_shape"),
            (.unreadable, "unreadable"),
            (.newerFormat, "newer_format"),
        ]
        #expect(causes.count == ProfileBrokenCause.allCases.count)
        core.configIssues = causes.map {
            ConfigIssue(
                source: "Work.json",
                kind: .profileBroken($0.0),
                profileName: "Work"
            )
        }
        let listed = try issues(core)
        try #require(listed.count == causes.count)
        for (issue, (_, name)) in zip(listed, causes) {
            #expect(issue["kind"] == .string("profile_broken"))
            #expect(issue["cause"] == .string(name))
            #expect(issue["profile"] == .string("Work"))
        }
    }

    @Test("every sync status is spelled with its fields")
    func everySyncStatusIsSpelled() throws {
        let core = makeTestCore()
        let newer = NewerFormatOnDisk(artifact: .guiConfig, format: 999)
        let cases: [(SyncStatus, [String: JSONValue])] = [
            (.off, ["status": .string("off")]),
            (.upToDate, ["status": .string("up_to_date")]),
            (.folderUnavailable, ["status": .string("folder_unavailable")]),
            (.changedOnBoth, ["status": .string("changed_on_both")]),
            (
                .conflictCopy("gui 2.json"),
                [
                    "status": .string("conflict_copy"),
                    "path": .string("gui 2.json"),
                ]
            ),
            (
                .newerOnAnotherMac(newer),
                [
                    "status": .string("newer_on_another_mac"),
                    "file": .string("gui.json"),
                ]
            ),
            (
                .newerHere(newer),
                [
                    "status": .string("newer_here"),
                    "file": .string("gui.json"),
                ]
            ),
        ]
        for (status, expected) in cases {
            core.sync.status = status
            var expected = expected
            expected["folder"] = .null
            #expect(try sync(core) == expected)
        }
    }

    @Test("a keep into a newer build's profile file says so")
    func keepNamesTheProfileLatch() throws {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        try Self.restamp(core.profiles.fileURL(name: "Odd"))
        #expect(
            try Self.refusal(core, width, "/settings/border/width")
                == "newer_format"
        )
    }

    @Test("a shared-look leaf over a newer gui.json is refused up front")
    func sharedLookLeafNamesTheLatch() throws {
        let core = try KeepFixture.core()
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        try Self.restamp(core.guiConfigStore.url)
        let again = KeepFixture.report(core, "border.set_width", [.number(8)])
        let leaf = KeepFixture.leaf(again, "/settings/border/width")
        #expect(leaf?.owner == .sharedLook)
        #expect(leaf?.notKeepable == .newerFormat)
        #expect(
            try Self.refusal(core, width, "/settings/border/width")
                == "newer_format"
        )
    }

    /// `file` re-stamped past any format this build knows.
    private static func restamp(_ file: URL) throws {
        var root = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: file))
                as? [String: Any]
        )
        let format = root["format"] as? Int ?? 0
        root["format"] = format + 1000
        try JSONSerialization.data(withJSONObject: root).write(to: file)
    }

    /// The keep's refusal of `id`, asked from `report`'s leaves.
    private static func refusal(
        _ core: KiwiCore,
        _ report: CommandResponse,
        _ id: String
    ) throws -> String? {
        let response = core.execute(
            KiwiCore.keepSettingsCommand,
            args: (report.changes?.touched ?? []).map { .string($0.id) }
        )
        #expect(response.isSuccess)
        guard case .object(let fields)? = response.data,
            case .array(let refused)? = fields["not_keepable"]
        else { return nil }
        for case .object(let leaf) in refused where leaf["id"] == .string(id) {
            return leaf["not_keepable"]?.stringValue
        }
        return nil
    }
}
