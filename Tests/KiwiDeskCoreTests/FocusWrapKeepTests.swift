import Foundation
import Testing

@testable import KiwiDeskCore

/// `set_focus_wrap` in `kiwidesk mcp`'s change report and its keep
/// (#2493, #1685): the `focus_wrap` root reports the live mode as
/// unkept, `keep_settings` writes it through the rule-reach door, and
/// the re-judge finds it stored — the `float_automatically` twin.
@Suite("Focus wrap keep (#2493)", .serialized)
@MainActor
struct FocusWrapKeepTests {
    private func ids(_ response: CommandResponse) -> [String] {
        (response.changes?.touched ?? []).map(\.id)
    }

    private func kept(_ response: CommandResponse) -> [String] {
        guard case .object(let fields)? = response.data,
            case .array(let items)? = fields["kept"]
        else { return [] }
        return items.compactMap { item in
            guard case .object(let leaf) = item else { return nil }
            return leaf["id"]?.stringValue
        }
    }

    @Test("a verb's change is reported unkept and keeps to gui.json")
    func focusWrapKeeps() throws {
        let core = try KeepFixture.core()
        #expect(core.guiConfigStore.load()?.focusWrap == .allScreens)
        let set = KeepFixture.report(
            core,
            "set_focus_wrap",
            [.string("off")]
        )
        let leaf = try #require(KeepFixture.leaf(set, "/focus_wrap"))
        #expect(leaf.owner == .sharedRules)
        #expect(!leaf.stored)
        let response = core.execute(
            KiwiCore.keepSettingsCommand,
            args: ids(set).map(JSONValue.string)
        )
        #expect(kept(response) == ["/focus_wrap"])
        #expect(core.guiConfigStore.load()?.focusWrap == .off)
    }

    /// The owner is `focus_wrap`'s own reach, never its twin's: with
    /// the profile holding `float_automatically` the two disagree, and
    /// `focus_wrap`, which it does not hold, stays shared.
    @Test("the owner reads focus_wrap's reach, not its twin's")
    func ownerIsItsOwnReach() throws {
        let core = try KeepFixture.core()
        var odd = KeepFixture.profile("Odd")
        odd.floatAutomatically = false
        try core.profiles.save(odd)
        KeepFixture.load("Odd", core)
        let set = KeepFixture.report(
            core,
            "set_focus_wrap",
            [.string("off")]
        )
        let leaf = try #require(KeepFixture.leaf(set, "/focus_wrap"))
        #expect(leaf.owner == .sharedRules)
    }
}
