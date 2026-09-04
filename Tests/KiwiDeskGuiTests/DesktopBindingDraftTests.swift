import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The draft's half of the re-key (#1147): Core rewrites the
/// sidecar's bindings when a renumber moves one onto its
/// Desktop's stamp, and a Settings window open across that
/// rewrite must not put the old number keys back on Save.
///
/// `.serialized`: the topology overrides are process-global.
@MainActor
@Suite("Desktop binding draft re-seed (#1147)", .serialized)
struct DesktopBindingDraftTests {
    private let stamp = DesktopIdentity(raw: "STAMP-A")

    private func makeModel() -> SettingsModel {
        makeTestModel(
            core: makeTestCore(
                configDirectory: FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "kiwi-draft-\(UUID().uuidString)"
                    )
            )
        )
    }

    /// A clean draft over `config` — the state a freshly-opened
    /// Settings window is in, without reaching the private
    /// target-state machinery.
    private func seed(_ model: SettingsModel, _ config: GuiConfig) {
        model.suppressDirty = true
        model.config = config
        model.suppressDirty = false
        model.cleanConfig = config
        model.savedSidecar = config
    }

    private func reset() {
        NativeSpaces.spacesOverride = nil
        NativeSpaces.mainDisplayUUIDOverride = nil
        NativeSpaces.activeSpaceIDOverride = nil
    }

    private func pin() {
        NativeSpaces.spacesOverride = [
            NativeSpace(
                id: 10,
                displayUUID: "UUID-A",
                isCurrent: true,
                identity: stamp
            )
        ]
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = 10
    }

    /// Core moved the binding to the stamp; the draft has not
    /// been touched, so it takes the rewrite — and the clean
    /// baseline moves with it, so nothing reads as unsaved.
    @Test("an untouched draft adopts Core's re-key")
    func untouchedDraftAdopts() throws {
        defer { reset() }
        pin()
        let model = makeModel()
        var stale = GuiConfig()
        stale.profileBindings = [
            .number(1): DesktopBinding(profile: "Work", desktop: 1)
        ]
        seed(model, stale)
        // Core's rewrite lands in the sidecar underneath it.
        var rekeyed = stale
        rekeyed.profileBindings = [
            .identity(stamp): DesktopBinding(
                profile: "Work",
                desktop: 1
            )
        ]
        try model.core.guiConfigStore.save(rekeyed)

        model.refreshProfiles()
        #expect(
            model.config.profileBindings[.identity(stamp)]?.profile
                == "Work"
        )
        #expect(model.config.profileBindings[.number(1)] == nil)
        // The BASELINE moved with the draft, compared as state
        // rather than read off `isDirty`: nothing on this path
        // recomputes that flag, so an assertion on it is answered
        // by its own initializer whatever the adopt did
        // (`guard-prover`, 2026-09-04). Left behind, the window
        // would nag about a change the user never made.
        #expect(
            model.config.profileBindings
                == model.cleanConfig.profileBindings
        )
        // …and the sidecar baseline too, which is the reader that
        // decides whether Save is offered at all.
        #expect(!model.globalsChanged)
    }

    /// The *current* badge is decided by the DESKTOP. A dormant
    /// record and a live Desktop can carry the same Mission
    /// Control number — delete a Desktop and a later one inherits
    /// it — and a number comparison then lights BOTH rows, which
    /// is what the owner's device round caught (2026-09-04).
    @Test("only the live Desktop is current, never its dormant twin")
    func currentIsKeyedByDesktop() {
        defer { reset() }
        pin()
        let model = makeModel()
        model.currentDesktop = 1
        model.currentDesktopKey = .identity(stamp)
        model.mainDesktops = [1]
        model.desktopKeys = [1: .identity(stamp)]
        model.presentDesktopKeys = [.identity(stamp), .number(1)]
        let ghost = DesktopKey.identity(DesktopIdentity(raw: "GONE"))
        model.config.profileBindings = [
            ghost: DesktopBinding(profile: "Old", desktop: 1)
        ]
        let rows = ProfilesFamilyRows.desktops(
            onMain: model.mainDesktops,
            keys: model.desktopKeys,
            present: model.presentDesktopKeys,
            bindings: model.config.profileBindings
        )
        // Two rows, one number, and exactly one of them current.
        #expect(rows.map(\.number) == [1, 1])
        #expect(
            rows.filter { $0.key == model.currentDesktopKey }.count
                == 1
        )
        #expect(rows.first { $0.isDormant }?.key == ghost)
    }

    /// …and that the VIEW asks that question, not the number's.
    /// The rows above cannot see which comparison the badge
    /// makes, and the badge is where the defect rendered.
    @Test("the current badge compares the Desktop, not the number")
    func currentBadgeIsKeyed() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/"
                        + "Profiles/DesktopsGroup.swift"
                )
        )
        #expect(
            source.contains("row.key == model.currentDesktopKey")
        )
        #expect(!source.contains("number == model.currentDesktop"))
    }

    /// Ownership is PER ENTRY: a user who edited one binding
    /// while Core re-keyed another keeps their edit AND takes the
    /// re-key. All-or-nothing let every untouched entry Save back
    /// under its old number key (architect review, 2026-09-04).
    @Test("one edited binding does not block the rest adopting")
    func adoptionIsPerEntry() throws {
        defer { reset() }
        pin()
        let model = makeModel()
        var stale = GuiConfig()
        stale.profileBindings = [
            .number(1): DesktopBinding(profile: "Work", desktop: 1),
            .number(2): DesktopBinding(profile: "Play", desktop: 2),
        ]
        seed(model, stale)
        // The user re-points Desktop 2 …
        model.config.profileBindings[.number(2)] = DesktopBinding(
            profile: "Edited",
            desktop: 2
        )
        // … while Core re-keys Desktop 1 onto its stamp.
        var rekeyed = stale
        rekeyed.profileBindings = [
            .identity(stamp): DesktopBinding(
                profile: "Work",
                desktop: 1
            ),
            .number(2): DesktopBinding(profile: "Play", desktop: 2),
        ]
        try model.core.guiConfigStore.save(rekeyed)

        model.refreshProfiles()
        #expect(
            model.config.profileBindings[.identity(stamp)]?.profile
                == "Work"
        )
        #expect(model.config.profileBindings[.number(1)] == nil)
        #expect(
            model.config.profileBindings[.number(2)]?.profile
                == "Edited"
        )
    }

    /// The mirror, and the reason this is not simply "always take
    /// the sidecar": a binding the user edited is theirs, and a
    /// refresh must not throw it away.
    @Test("an edited draft keeps the user's binding")
    func editedDraftIsKept() throws {
        defer { reset() }
        pin()
        let model = makeModel()
        var stale = GuiConfig()
        stale.profileBindings = [
            .number(1): DesktopBinding(profile: "Work", desktop: 1)
        ]
        seed(model, stale)
        model.config.profileBindings[.number(1)] = DesktopBinding(
            profile: "Play",
            desktop: 1
        )
        var rekeyed = stale
        rekeyed.profileBindings = [
            .identity(stamp): DesktopBinding(
                profile: "Work",
                desktop: 1
            )
        ]
        try model.core.guiConfigStore.save(rekeyed)

        model.refreshProfiles()
        #expect(
            model.config.profileBindings[.number(1)]?.profile
                == "Play"
        )
    }
}
