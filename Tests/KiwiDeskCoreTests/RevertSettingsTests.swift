import Foundation
import Testing

@testable import KiwiDeskCore

/// `revert_settings` (#2411), `keep_settings`' twin: the named
/// unsaved live leaves go back to the value their owner stores,
/// applied live; the other leaves stay as they are live.
@Suite("Revert settings", .serialized)
@MainActor
struct RevertSettingsTests {
    private let width = "/settings/border/width"

    private func revert(
        _ core: KiwiCore,
        _ ids: [String]
    ) -> CommandResponse {
        core.execute(
            KiwiCore.revertSettingsCommand,
            args: ids.map(JSONValue.string)
        )
    }

    private func ids(_ data: JSONValue?, _ key: String) -> [String] {
        guard case .object(let fields)? = data,
            case .array(let items)? = fields[key]
        else { return [] }
        return items.compactMap(\.stringValue)
    }

    /// `not_revertable`'s entries, id to reason.
    private func refusals(_ data: JSONValue?) -> [String: String] {
        guard case .object(let fields)? = data,
            case .array(let items)? = fields["not_revertable"]
        else { return [:] }
        var out: [String: String] = [:]
        for case .object(let leaf) in items {
            if let id = leaf["id"]?.stringValue {
                out[id] = leaf["reason"]?.stringValue
            }
        }
        return out
    }

    /// A core whose live profile keeps its own look.
    private func ownLookCore() throws -> KiwiCore {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        return core
    }

    @Test("a named leaf goes back live")
    func namedLeafGoesBack() throws {
        for core in [try ownLookCore(), try KeepFixture.core()] {
            let stored = core.tiler.settings.borderStyle.width
            _ = core.execute("border.set_width", args: [.number(9)])
            let response = revert(core, [width])
            #expect(response.isSuccess)
            #expect(ids(response.data, "reverted") == [width])
            #expect(refusals(response.data).isEmpty)
            #expect(core.tiler.settings.borderStyle.width == stored)
            #expect(core.unsavedLiveSettings() == nil)
        }
    }

    @Test("a leaf left out stays live")
    func otherLeavesStay() throws {
        let core = try ownLookCore()
        let stored = core.tiler.settings.borderStyle.width
        _ = core.execute("border.set_width", args: [.number(9)])
        _ = core.execute(
            "set_space_icon",
            args: [.string("1"), .string("star")]
        )
        let unsaved = try #require(core.unsavedLiveSettings())
        let icon = try #require(
            unsaved.leaves.keys.first { $0 != width }
        )
        #expect(revert(core, [icon]).isSuccess)
        #expect(core.tiler.settings.spaceIcons[SpaceID("1")] == nil)
        #expect(core.tiler.settings.borderStyle.width == 9)
        #expect(core.tiler.settings.borderStyle.width != stored)
        #expect(core.unsavedLiveSettings()?.leaves.keys.sorted() == [width])
    }

    @Test("a leaf already stored is reverted without a write")
    func storedLeafCounts() throws {
        let core = try ownLookCore()
        let before = core.tiler.settings
        let response = revert(core, [width])
        #expect(ids(response.data, "reverted") == [width])
        #expect(core.tiler.settings == before)
    }

    /// The refusals: outside `settings`, no pointer at all, and a
    /// leaf no keep could write (a temporary Space's icon), whose
    /// live value stays.
    @Test("what it cannot put back is refused, and stays live")
    func refusals() throws {
        let core = try ownLookCore()
        _ = core.execute("focus_space", args: [.string("8")])
        _ = core.execute(
            "set_space_icon",
            args: [.string("8"), .string("star")]
        )
        let temporary = "/settings/space_icons/8"
        let response = revert(
            core,
            ["/space_modes/1", "not a pointer", temporary]
        )
        #expect(response.isSuccess)
        #expect(ids(response.data, "reverted").isEmpty)
        #expect(
            refusals(response.data) == [
                "/space_modes/1": "not_a_setting",
                "not a pointer": "not_a_setting",
                temporary: "not_keepable",
            ]
        )
        #expect(core.tiler.settings.spaceIcons[SpaceID("8")] == "star")
    }

    @Test("the verb needs leaf ids")
    func needsIds() throws {
        let core = try KeepFixture.core()
        #expect(!revert(core, []).isSuccess)
        #expect(
            !core.execute(
                KiwiCore.revertSettingsCommand,
                args: [.number(1)]
            ).isSuccess
        )
    }

    @Test("the verb is CLI-only and destructive")
    func registers() {
        #expect(
            APIReference.cliOnly.contains(KiwiCore.revertSettingsCommand)
        )
        #expect(
            APIReference.destructive.contains(KiwiCore.revertSettingsCommand)
        )
    }
}
