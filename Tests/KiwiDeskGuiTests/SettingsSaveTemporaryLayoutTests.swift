import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Settings Save neither reverts nor adopts a standing
/// temporary layout (#1179, the condition-5 ruling).
///
/// "Settings saves what you edited; temporary layouts stay
/// temporary until you keep them." Per space: a real draft edit
/// wins and overwrites the temp for that space; every other
/// space's temp survives on screen and stays out of the file.
///
/// Both leaks close together and each is the other's mirror.
/// Before this, Save re-asserted the draft's modes wholesale
/// (destroying the temp — the reported bug), while the draft's
/// modes seeded from LIVE (adopting the temp into the file —
/// the same violation pointing the other way).
@Suite("Settings Save vs. a temporary layout", .serialized)
@MainActor
struct SettingsSaveTemporaryLayoutTests {
    private static let kept = SpaceID("1")
    private static let edited = SpaceID("2")

    /// A core with two spaces under a saved profile that puts
    /// both on `.bsp`, and a model seeded from it.
    private func makeSeeded() throws -> (SettingsModel, KiwiCore) {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: frame,
                visibleFrame: frame
            )
        )
        let profile = Profile(
            name: "test-profile",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [Self.kept, Self.edited],
            spaceModes: [Self.kept: .bsp, Self.edited: .bsp],
            settings: TilingSettings()
        )
        try core.profiles.save(profile)
        _ = core.execute(
            "load_profile",
            args: [.string("test-profile")]
        )
        let model = makeTestModel(core: core)
        model.reload()
        return (model, core)
    }

    private func savedMode(
        _ core: KiwiCore,
        _ space: SpaceID
    ) throws -> LayoutMode? {
        try core.profiles.read(name: "test-profile")
            .spaceModes[space]
    }

    @Test("An untouched space keeps its temp on screen and off disk")
    func aTempSurvivesAnUnrelatedSave() throws {
        let (model, core) = try makeSeeded()

        // A quick-menu switch: session-only, on a space the
        // draft never touches.
        core.state.workspaces.setMode(Self.kept, .monocle)
        // An unrelated Settings edit, the kind the pill counts.
        model.config.settings.minWindowSize = 321
        #expect(model.isDirty)

        model.updateActiveProfile()

        // The unrelated edit landed...
        #expect(core.tiler.settings.minWindowSize == 321)
        // ...the temp is still on screen...
        #expect(
            core.state.workspaces[Self.kept]?.mode == .monocle
        )
        // ...and it stayed out of the file. Both halves: a Save
        // that re-asserted the draft would have reverted the
        // screen, and one that captured live would have written
        // `.monocle` here.
        #expect(try savedMode(core, Self.kept) == .bsp)
    }

    @Test("A staged mode edit wins over the temp on its own space")
    func anEditedSpaceOverwritesItsTemp() throws {
        let (model, core) = try makeSeeded()

        core.state.workspaces.setMode(Self.edited, .monocle)
        // The user says, in Settings, what this space should be.
        model.config.spaceModes[Self.edited] = .stack
        #expect(model.isDirty)

        model.updateActiveProfile()

        #expect(
            core.state.workspaces[Self.edited]?.mode == .stack
        )
        #expect(try savedMode(core, Self.edited) == .stack)
    }

    @Test("One Save decides both spaces independently")
    func theMixedCase() throws {
        // The whole ruling in one run: a temp on one space, an
        // edit on the other, one Save.
        let (model, core) = try makeSeeded()

        core.state.workspaces.setMode(Self.kept, .monocle)
        core.state.workspaces.setMode(Self.edited, .monocle)
        model.config.spaceModes[Self.edited] = .stack

        model.updateActiveProfile()

        #expect(
            core.state.workspaces[Self.kept]?.mode == .monocle
        )
        #expect(try savedMode(core, Self.kept) == .bsp)
        #expect(
            core.state.workspaces[Self.edited]?.mode == .stack
        )
        #expect(try savedMode(core, Self.edited) == .stack)
    }

    @Test("Editing a mode back to its saved value is not an edit")
    func editThenEditBackIsUnedited() throws {
        // Stated residue (b) of the ruling: editing a mode back
        // to its saved value neither saves nor kills a standing
        // temp. It falls out of reading "edited" off the diff
        // rather than latching a flag — the popover row vanishes
        // for the same reason.
        let (model, core) = try makeSeeded()

        core.state.workspaces.setMode(Self.kept, .monocle)
        model.config.spaceModes[Self.kept] = .stack
        model.config.spaceModes[Self.kept] = nil
        model.config.settings.minWindowSize = 321

        model.updateActiveProfile()

        #expect(
            core.state.workspaces[Self.kept]?.mode == .monocle
        )
        #expect(try savedMode(core, Self.kept) == .bsp)
    }

    @Test("The popover lists exactly the spaces a Save writes")
    func popoverRowsMatchTheDiff() throws {
        // The ruling's obligation 1, held BEHAVIOURALLY rather
        // than by a source needle. A scan for the call was
        // fail-open by spelling twice over (guard-prover,
        // 2026-08-31): a re-derivation written `?? LayoutMode
        // .bsp` missed the needle, and a comment naming the
        // symbol satisfied the positive clause with no call in
        // the file at all.
        //
        // What cannot be spelled around: the unsaved-changes
        // popover's ROWS and the set a Save writes come from one
        // answer, so changing either alone reds this. The pill
        // is the draft's one narrator — a space a Save writes
        // that the popover never listed is the failure.
        let (model, core) = try makeSeeded()
        _ = core

        core.state.workspaces.setMode(Self.kept, .monocle)
        model.config.spaceModes[Self.edited] = .stack
        model.config.settings.minWindowSize = 321

        let diff = SettingsDraftDiff.between(
            config: model.config,
            cleanConfig: model.cleanConfig,
            luaSource: model.luaSource,
            cleanLuaSource: model.cleanLuaSource
        )
        let listed = Set(
            SettingsValueReadout.rows(
                for: .spaces(.spaceModes),
                old: model.cleanConfig,
                new: model.config
            )
            .compactMap { row in
                SpaceID(
                    String(
                        row.id.split(separator: "#").last ?? ""
                    )
                )
            }
        )
        #expect(listed == diff.editedSpaceModes)
        // Non-empty, or the equality above is two empty sets:
        // the temp on `kept` is deliberately NOT in either.
        #expect(listed == [Self.edited])
    }

    @Test("The edited set names only spaces whose mode moved")
    func editedSetIsExactlyTheChangedModes() throws {
        // The ruling's own obligation 1: apply and persist
        // consult `SettingsDraftDiff`'s attribution — the same
        // seam the pill count and the unsaved popover read — and
        // never a comparison re-derived beside the apply. Read
        // the predicate directly, because a re-derivation that
        // happens to agree today is exactly what this forbids.
        let (model, core) = try makeSeeded()
        _ = core

        model.config.spaceModes[Self.edited] = .stack
        model.config.settings.minWindowSize = 321

        let diff = SettingsDraftDiff.between(
            config: model.config,
            cleanConfig: model.cleanConfig,
            luaSource: model.luaSource,
            cleanLuaSource: model.cleanLuaSource
        )
        #expect(diff.editedSpaceModes == [Self.edited])
        // The unrelated size edit is counted, and it names no
        // space — a scope taken from "anything changed" would
        // have swept both.
        #expect(diff.total > 1)
    }

    @Test("A capture-live write tells the draft; a commit does not")
    func onlyCaptureLiveNotifiesTheDraft() throws {
        // The debt is owed by the WRITE, not by the menu row
        // (architect review, 2026-08-31): `save_profile` from
        // Lua, the CLI or IPC is a second capture-live path, and
        // with Settings open it would otherwise leave the
        // draft's baseline on the pre-save modes for the next
        // Save to write back — this issue's own failure, one
        // channel over.
        let (model, core) = try makeSeeded()
        var captured: [String] = []
        core.onProfileCapturedLive = { captured.append($0) }

        // The command path pays it...
        #expect(
            core.execute(
                "save_profile",
                args: [.string("test-profile")]
            ).isSuccess
        )
        #expect(captured == ["test-profile"])

        // ...and a draft commit does not: it wrote the draft's
        // own modes, so the baseline is already right.
        captured = []
        model.config.settings.minWindowSize = 321
        model.updateActiveProfile()
        #expect(captured.isEmpty)
    }
}
