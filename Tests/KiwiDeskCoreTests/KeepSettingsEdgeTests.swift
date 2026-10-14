import Foundation
import Testing

@testable import KiwiDeskCore

/// `keep_settings`' refusals and its re-judged answer (#1685): a
/// stale epoch, a map entry whose leaves all left, a value already
/// stored and a write that did not land.
@Suite("Keep settings — edges", .serialized)
@MainActor
struct KeepSettingsEdgeTests {
    private func keep(_ core: KiwiCore, _ ids: [String]) -> CommandResponse {
        core.execute(
            KiwiCore.keepSettingsCommand,
            args: ([core.settingsEpoch] + ids).map(JSONValue.string)
        )
    }

    private func ids(_ data: JSONValue?, _ key: String) -> [String] {
        guard case .object(let fields)? = data,
            case .array(let items)? = fields[key]
        else { return [] }
        return items.compactMap { item in
            guard case .object(let leaf) = item else { return nil }
            return leaf["id"]?.stringValue
        }
    }

    private func odd(_ core: KiwiCore, gaps: Bool = false) throws {
        var profile = KeepFixture.profile("Odd")
        if gaps {
            profile.settings.gapsOverride["1"] = Gaps(
                outer: Gaps.Outer(top: 3, bottom: 3, left: 3, right: 3)
            )
        }
        try core.profiles.save(profile)
        KeepFixture.load("Odd", core)
    }

    @Test("a keep after a load is refused whole")
    func staleEpochRefuses() throws {
        let core = try KeepFixture.core()
        try odd(core)
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        let epoch = core.settingsEpoch
        KeepFixture.load("Odd", core)
        #expect(core.settingsEpoch != epoch)
        let ids = (width.changes?.touched ?? []).map(\.id)
        let response = core.execute(
            KiwiCore.keepSettingsCommand,
            args: ([epoch] + ids).map(JSONValue.string)
        )
        #expect(!response.isSuccess)
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.settings.borderStyle.width != 9)
    }

    @Test("a map entry whose leaves all left is kept as gone")
    func removedEntryKeeps() throws {
        let core = try KeepFixture.core()
        try odd(core, gaps: true)
        #expect(core.tiler.settings.gapsOverride["1"] != nil)
        let before = core.keepDocument
        core.tiler.settings.gapsOverride["1"] = nil
        let paths = KeepPointer.diff(before, core.keepDocument)
        #expect(!paths.isEmpty)
        let response = keep(core, paths.map(KeepPointer.string))
        #expect(response.isSuccess)
        #expect(ids(response.data, "not_keepable").isEmpty)
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.settings.gapsOverride["1"] == nil)
    }

    @Test("a temporary Space's own settings are not keepable")
    func temporarySpaceKeyedLeaf() throws {
        let core = try KeepFixture.core()
        _ = core.execute("set_mode", args: [.string("9"), .string("bsp")])
        let icon = KeepFixture.report(
            core,
            "set_space_icon",
            [.string("9"), .string("star")]
        )
        let leaf = KeepFixture.leaf(icon, "/settings/space/icon/9")
        #expect(leaf?.notKeepable == .temporarySpace)
        let declared = KeepFixture.report(
            core,
            "set_space_icon",
            [.string("1"), .string("star")]
        )
        let one = KeepFixture.leaf(declared, "/settings/space/icon/1")
        #expect(one?.notKeepable == nil)
    }

    @Test("a value already stored is kept without a write")
    func storedNeedsNoWrite() throws {
        let core = try KeepFixture.core()
        try odd(core)
        var writes = 0
        core.onLiveProfileWritten = { _, _ in writes += 1 }
        let response = keep(core, ["/settings/border/width"])
        #expect(ids(response.data, "kept") == ["/settings/border/width"])
        #expect(writes == 0)
    }

    @Test("keeping one look leaf leaves another pending live")
    func partialKeepKeepsOthersLive() throws {
        let core = try KeepFixture.core()
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        let glow = KeepFixture.report(
            core,
            "border.set_glow_size",
            [.number(7)]
        )
        let glowIDs = (glow.changes?.touched ?? []).map(\.id)
        #expect(!glowIDs.isEmpty)
        let epoch = core.settingsEpoch
        let response = keep(core, (width.changes?.touched ?? []).map(\.id))
        #expect(!ids(response.data, "kept").isEmpty)
        #expect(core.settingsEpoch == epoch)
        let still = core.answer(.reporting("version", watch: glowIDs))
        #expect(still.changes?.watched.allSatisfy { !$0.stored } == true)
    }

    @Test("a path no side holds is unknown, never kept")
    func unknownPathIsRefused() throws {
        let core = try KeepFixture.core()
        let response = keep(core, ["/settings/gap/globl"])
        #expect(ids(response.data, "kept").isEmpty)
        #expect(ids(response.data, "not_keepable") == ["/settings/gap/globl"])
    }

    @Test("half of a new map entry is refused as conflicting")
    func halfAnEntryConflicts() throws {
        let core = try KeepFixture.core()
        try odd(core)
        let before = core.keepDocument
        core.tiler.settings.gapsOverride["1"] = Gaps(
            outer: Gaps.Outer(top: 3, bottom: 4, left: 5, right: 6)
        )
        let paths = KeepPointer.diff(before, core.keepDocument)
        #expect(paths.count > 1)
        let first = try #require(paths.first)
        let response = keep(core, [KeepPointer.string(first)])
        #expect(ids(response.data, "kept").isEmpty)
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.settings.gapsOverride["1"] == nil)
    }

    @Test("a write that does not land is answered not written")
    func unwrittenIsRefused() throws {
        let core = try KeepFixture.core()
        try odd(core)
        let width = KeepFixture.report(core, "border.set_width", [.number(9)])
        let dir = core.profiles.directory
        let fm = FileManager.default
        try fm.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: dir.path
        )
        defer {
            try? fm.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: dir.path
            )
        }
        let file = dir.appendingPathComponent("Odd.json")
        try? fm.setAttributes(
            [.posixPermissions: 0o444],
            ofItemAtPath: file.path
        )
        defer {
            try? fm.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: file.path
            )
        }
        let response = keep(core, (width.changes?.touched ?? []).map(\.id))
        #expect(response.isSuccess)
        #expect(ids(response.data, "kept").isEmpty)
        #expect(
            ids(response.data, "not_keepable") == ["/settings/border/width"]
        )
    }
}
