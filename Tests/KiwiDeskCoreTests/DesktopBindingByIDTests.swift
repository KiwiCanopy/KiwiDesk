import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A binding names its profile by id (#2324 ruling 11): a rename
/// follows, a deleted profile reads as MISSING — never unreadable —
/// and a different profile that took the old name never answers
/// for it. A pending name gains the id once its profile exists.
@MainActor
@Suite("Desktop bindings by profile id (#2324)")
struct DesktopBindingByIDTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "D1",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        return core
    }

    @discardableResult
    private func save(_ core: KiwiCore, _ name: String) throws -> Profile {
        try core.profiles.write(
            Profile(
                name: name,
                monitorSets: [MonitorSet(monitors: ["D1:100x100"])],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
    }

    private func binding(_ entry: DesktopBinding.Entry) -> DesktopBinding {
        DesktopBinding(entries: [entry], desktop: 1)
    }

    @Test("A rename keeps the binding on its profile")
    func renameFollows() throws {
        let core = makeCore()
        let work = try save(core, "Work")
        let bound = binding(.init(id: work.id, name: "Work"))
        try core.profiles.rename(from: "Work", to: "Office")
        let pick = try core.boundProfile(of: bound).get()
        #expect(pick.profile.name == "Office")
    }

    @Test("A deleted profile reads as missing, never unreadable")
    func deletedReadsMissing() throws {
        let core = makeCore()
        let work = try save(core, "Work")
        try core.profiles.delete(name: "Work")
        let result = core.boundProfile(
            of: binding(.init(id: work.id, name: "Work"))
        )
        guard case .failure(.missing(let names)) = result else {
            Issue.record("expected missing, got \(result)")
            return
        }
        #expect(names == ["Work"])
    }

    @Test("A file that will not decode stays unreadable")
    func corruptReadsUnreadable() throws {
        let core = makeCore()
        try save(core, "Work")
        let url = try core.profiles.fileURL(name: "Work")
        try Data("not json".utf8).write(to: url)
        let result = core.boundProfile(
            of: binding(.init(name: "Work"))
        )
        guard case .failure(.unreadable) = result else {
            Issue.record("expected unreadable, got \(result)")
            return
        }
    }

    /// An id whose file exists and will not decode — corrupt, or a
    /// newer build's on a synced folder — is unreadable, never
    /// missing: "missing" would offer to drop another Mac's profile.
    @Test(
        "An id's undecodable file stays unreadable",
        arguments: ["corrupt", "newer"]
    )
    func idFileUndecodableIsUnreadable(_ kind: String) throws {
        let core = makeCore()
        let work = try save(core, "Work")
        let url = try core.profiles.fileURL(name: "Work")
        let body =
            kind == "corrupt"
            ? #"{"id":"\#(work.id.raw)","name":"Work"}"#
            : #"{"format":999,"id":"\#(work.id.raw)","name":"Work"}"#
        try Data(body.utf8).write(to: url)
        let result = core.boundProfile(
            of: binding(.init(id: work.id, name: "Work"))
        )
        guard case .failure(.unreadable) = result else {
            Issue.record("expected unreadable, got \(result)")
            return
        }
    }

    /// A file rewritten in place moves no folder stamp; the gate
    /// still refuses a file that no longer carries the id.
    @Test("A file that lost the id does not answer for it")
    func inPlaceEditIsChecked() throws {
        let core = makeCore()
        let work = try save(core, "Work")
        _ = core.profiles.profileName(withID: work.id)
        var other = try core.profiles.read(name: "Work")
        other.id = .fresh()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(other).write(
            to: try core.profiles.fileURL(name: "Work")
        )
        let result = core.boundProfile(
            of: binding(.init(id: work.id, name: "Work"))
        )
        guard case .failure(.missing) = result else {
            Issue.record("expected missing, got \(result)")
            return
        }
    }

    /// The twin of `theNumberDoesNotCarryTheBinding`: a new profile
    /// under the old name is not the one the binding names.
    @Test("The name does not carry the binding")
    func nameDoesNotCarry() throws {
        let core = makeCore()
        let work = try save(core, "Work")
        try core.profiles.delete(name: "Work")
        try save(core, "Work")
        let result = core.boundProfile(
            of: binding(.init(id: work.id, name: "Work"))
        )
        guard case .failure(.missing) = result else {
            Issue.record("expected missing, got \(result)")
            return
        }
    }

    @Test("The verb binds a saved profile by its id")
    func verbStoresTheID() throws {
        let core = makeCore()
        let work = try save(core, "Work")
        #expect(core.bindingEntry(named: "Work").id == work.id)
        #expect(core.bindingEntry(named: "Later").id == nil)
    }

    /// A pending name promotes to the file's id, and to the legacy
    /// id of a profile renamed before ids existed.
    @Test("A pending name gains its profile's id")
    func pendingPromotes() throws {
        let core = makeCore()
        try core.guiConfigStore.saveIncludingBindings(GuiConfig())
        let work = try save(core, "Work")
        var renamed = Profile(
            id: .legacy(name: "Old"),
            name: "Renamed",
            monitorSets: [MonitorSet(monitors: ["D1:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        renamed = try core.profiles.write(renamed)
        let pending: [DesktopKey: DesktopBinding] = [
            .number(1): DesktopBinding(profiles: ["Work"], desktop: 1),
            .number(2): DesktopBinding(profiles: ["Old"], desktop: 2),
            .number(3): DesktopBinding(profiles: ["Nobody"], desktop: 3),
        ]
        try core.guiConfigStore.saveBindings(pending)
        core.desktopBindings = pending
        core.promotePendingBindings()
        let stored = core.guiConfigStore.bindingsFile.load().profileBindings
        #expect(stored[.number(1)]?.entries.first?.id == work.id)
        #expect(stored[.number(2)]?.entries.first?.id == renamed.id)
        #expect(stored[.number(3)]?.entries.first?.id == nil)
        #expect(core.desktopBindings[.number(1)]?.entries.first?.id == work.id)
    }
}
