import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Completion's live names read Core's own answers (#1685 ▸ Ruling
/// 6e): each source is parsed from what a real core sends, so a
/// renamed key reds here rather than leaving completion empty.
/// Spends one test core per test on the main actor.
@MainActor
@Suite("CLI live completion values")
struct CLILiveValuesTests {
    static func names(
        _ source: CLILiveValues.Source,
        from core: KiwiCore
    ) -> [String] {
        let request = CLILiveValues.request(for: source)
        let response = core.execute(request.command)
        guard let data = response.data else { return [] }
        return CLILiveValues.names(source, in: data)
    }

    @Test("Space and window ids come from get_state")
    func spacesAndWindows() {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace(SpaceID("dev"))
        core.state.workspaces.activate("dev")
        let window = ManagedWindow(
            id: WindowID(4711),
            pid: 900_001,
            appName: "Notes",
            appBundleID: "app.test.notes"
        )
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(4711), to: "dev")
        #expect(Self.names(.spaces, from: core).contains("dev"))
        #expect(Self.names(.windows, from: core) == ["4711"])
    }

    @Test("profile names come from list_profiles")
    func profiles() {
        let core = makeTestCore()
        let saved = core.execute("save_profile", args: [.string("Mine")])
        #expect(saved.isSuccess, "\(saved.error ?? "")")
        #expect(Self.names(.profiles, from: core).contains("Mine"))
    }

    @Test("look names come from look.list")
    func looks() {
        let core = makeTestCore()
        let names = Self.names(.looks, from: core)
        #expect(!names.isEmpty, "no bundled look listed")
        let bundled = core.bundledLooks.map(\.name)
        #expect(Array(names.prefix(bundled.count)) == bundled)
    }

    @Test("look.delete offers saved looks, never a bundled one")
    func savedLooks() {
        let core = makeTestCore()
        let saved = core.execute("look.save", args: [.string("Mine")])
        #expect(saved.isSuccess, "\(saved.error ?? "")")
        let names = Self.names(.savedLooks, from: core)
        #expect(names == ["Mine"])
        #expect(Self.names(.looks, from: core).contains("Mine"))
    }
}
