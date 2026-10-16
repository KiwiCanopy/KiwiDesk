import AppKit
import Testing

@testable import KiwiDeskCore

/// The window switcher lists a lens's apps first (#2103 ruling
/// 36): while a lens is on its apps' rows lead, the others follow
/// marked `isOtherApp`, each part keeping its own order, and a
/// search keeps the two apart; with no lens on nothing moves.
@Suite("KiwiVision lens window switcher order", .serialized)
@MainActor
struct KiwiVisionLensJumpTests {
    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        let core = makeTestCore()
        core.eventLoop.runningApplications = { [] }
        core.eventLoop.ownKeyWindow = { nil }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        for (id, app, bundle, title) in [
            (UInt32(1), "Mail", "test.kiwi.mail", ""),
            (2, "Notes", "test.kiwi.notes", "Mail merge"),
            (3, "Mail", "test.kiwi.mail", ""),
        ] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 900_041,
                        appName: app,
                        appBundleID: bundle,
                        title: title
                    )
                )
            )
            core.state.workspaces.add(WindowID(id), to: "1")
            core.state.stampFocusRecency(WindowID(id))
        }
        let lens: [String: JSONValue] = [
            "name": .string("Writing"),
            "apps": .array([.string("test.kiwi.notes")]),
        ]
        core.execute("kiwivision.define_lens", args: [.object(lens)])
        return core
    }

    private func windows(_ rows: [JumpEntry]) -> [UInt32] {
        rows.compactMap {
            guard case .window(let id) = $0.target else { return nil }
            return id.raw
        }
    }

    @Test("a lens's apps lead, the others follow marked")
    func membersLead() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        #expect(windows(core.jumpEntries()) == [3, 2, 1])
        #expect(core.jumpEntries().allSatisfy { !$0.isOtherApp })
        core.setKiwiVision(.lens("Writing"))
        let rows = core.jumpEntries()
        #expect(windows(rows) == [2, 3, 1])
        #expect(rows.map(\.isOtherApp) == [false, true, true])
    }

    @Test("a search keeps the lens's apps ahead")
    func searchKeepsTheSplit() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.setKiwiVision(.lens("Writing"))
        // "mail" matches Mail by name, Notes only by a title.
        let found = JumpSearch.matches(core.jumpEntries(), query: "mail")
        #expect(windows(found.map(\.entry)).first == 2)
    }
}
