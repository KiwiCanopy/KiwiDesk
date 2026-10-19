import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// What the sync sheet counts and keeps (#2450): the summary line
/// folds per member at the sheet alone, a question's writer-covered
/// settings are no "other" change, and an answer settles only the
/// conflicts its sheet showed. Main-actor cost: one test core and
/// model per test, plus one source read. Split from
/// `SyncReviewTests` at the file ceiling.
@Suite("The sync sheet's counts", .serialized)
@MainActor
struct SyncReviewCountTests {
    private let change = SyncedChange(paths: ["gui.json"], mac: "Studio")

    private func setup() throws -> (KiwiCore, SettingsModel) {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-sync-count-\(UUID())")
        )
        core.onLog = { _ in }
        try core.guiConfigStore.save(GuiConfig())
        core.loadConfig()
        let model = makeTestModel(core: core)
        model.reload()
        return (core, model)
    }

    private func theirs(
        _ core: KiwiCore,
        _ edit: (inout GuiConfig) -> Void
    ) throws {
        var stored = try #require(core.guiConfigStore.load())
        edit(&stored)
        try core.guiConfigStore.save(stored)
        core.loadConfig()
    }

    /// One control's edges arriving over two changes count once.
    @Test("a group taken in over two arrivals counts once")
    func takenFoldsOnce() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        core.tiler.settings.gapsGlobal.outer.top = 2
        model.adoptSyncedChange(change)
        core.tiler.settings.gapsGlobal.outer = .init(
            top: 6,
            bottom: 6,
            left: 6,
            right: 6
        )
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        #expect(model.sync.review?.taken == 1)
    }

    /// The Space Bar's edge writer lays the draft's edge back over
    /// the other Mac's per-screen map: that map is the question's,
    /// never "taken in" nor one of the draft's other edits.
    @Test("a setting a question covers is in neither count")
    func coveredIsNotCounted() throws {
        let (core, model) = try setup()
        model.config.settings.spaceBarStyle.edge = .bottom
        core.tiler.settings.spaceBarStyle.edgeOverride = ["S": .left]
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        let review = try #require(model.sync.review)
        #expect(review.rows.count == 1)
        #expect(review.taken == 0)
        #expect(review.yourOthers == 0)
    }

    /// A question asked again on a second arrival keeps the
    /// settings its writer covered.
    @Test("a re-asked question keeps what it covered")
    func reaskKeepsCovers() throws {
        let (core, model) = try setup()
        model.config.settings.spaceBarStyle.edge = .bottom
        core.tiler.settings.spaceBarStyle.edgeOverride = ["S": .left]
        model.adoptSyncedChange(change)
        core.tiler.settings.spaceBarStyle.edge = .left
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        let review = try #require(model.sync.review)
        #expect(review.rows.count == 1, "\(review.rows.map(\.id))")
        #expect(review.yourOthers == 0)
    }

    /// A setting taken in and edited by the draft since is the
    /// draft's edit, never also "taken in".
    @Test("a taken setting edited since counts once, as yours")
    func takenThenEditedIsYours() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) {
            $0.modeCycle = [.bsp, .stack]
            $0.spaceHistory = .allScreens
        }
        model.adoptSyncedChange(change)
        model.config.spaceHistory = .perScreen
        #expect(model.reviewSyncConflicts())
        let review = try #require(model.sync.review)
        #expect(review.taken == 0)
        #expect(review.yourOthers == 1)
    }

    /// A mixed minimum size lists only the axis that differs.
    @Test("a mixed group lists only its differing axis")
    func mixedListsOnlyItsAxis() throws {
        LocalizationManager.shared.select("en")
        let (core, model) = try setup()
        model.setMinSize(420, axis: .width, for: nil)
        core.tiler.settings.minWindowSizes.stack.width = 250
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        let row = try #require(model.sync.review?.rows.first)
        #expect(row.key == .behaviour(.minWindowSize))
        // Six widths listed, no height.
        #expect(row.theirs.components(separatedBy: ": ").count == 7)
    }

    /// An arrival while the sheet is up closes it: the values it
    /// showed moved, and the next Save asks again.
    @Test("an arrival closes an open sheet")
    func arrivalClosesTheSheet() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        try theirs(core) { $0.modeCycle = [.grid, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.sync.review == nil)
        #expect(model.sync.conflicts.map(\.key) == [.shortcuts(.modeCycle)])
    }

    /// A conflict the sheet never showed stays for the next Save.
    @Test("an answer settles only the conflicts it showed")
    func answerKeepsUnshown() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        let late = SyncConflict(
            key: .shortcuts(.spaceHistory),
            label: "late",
            yours: "a",
            theirs: "b",
            mac: nil
        )
        model.sync.conflicts.append(late)
        model.answerSyncReview(
            [SettingKey.shortcuts(.modeCycle).id: .yours]
        )
        #expect(model.sync.conflicts.map(\.key) == [late.key])
    }

    /// The live list never folds a group over an edge the draft's
    /// own row narrates.
    @Test("a live group with a draft-edited edge lists apart")
    func liveFoldStandsApart() {
        let model = makeTestModel()
        var saved = model.cleanConfig.settings
        saved.gapsGlobal.outer = .init(top: 2, bottom: 2, left: 2, right: 2)
        var live = saved
        live.gapsGlobal.outer = .init(top: 9, bottom: 9, left: 9, right: 9)
        model.cleanConfig.settings = live
        model.config = model.cleanConfig
        model.config.settings.gapsGlobal.outer.top = 30
        model.unsavedLive = UnsavedLiveSettings(
            saved: saved,
            live: live,
            leaves: [:]
        )
        let liveKeys = SettingsDiffRowSource.rows(for: model)
            .filter { $0.section == .live }.map(\.key)
        #expect(
            liveKeys
                == [
                    .gaps(.outerBottom), .gaps(.outerLeft),
                    .gaps(.outerRight),
                ]
        )
    }

    /// The draft's row never folds a group whose other edges the
    /// live rows list.
    @Test("a draft group with live edges lists apart")
    func draftFoldStandsApartFromLive() {
        let model = makeTestModel()
        var saved = model.cleanConfig.settings
        saved.gapsGlobal.outer = .init(top: 2, bottom: 2, left: 2, right: 2)
        var live = saved
        live.gapsGlobal.outer.top = 9
        live.gapsGlobal.outer.bottom = 9
        model.cleanConfig.settings = live
        model.config = model.cleanConfig
        model.config.settings.gapsGlobal.outer.left = 9
        model.config.settings.gapsGlobal.outer.right = 9
        model.unsavedLive = UnsavedLiveSettings(
            saved: saved,
            live: live,
            leaves: [:]
        )
        let draftKeys = SettingsDiffRowSource.rows(for: model)
            .filter { $0.section != .live }.map(\.key)
        #expect(draftKeys == [.gaps(.outerLeft), .gaps(.outerRight)])
    }

    /// The pick runs the footer's Save, so the sheet names it the
    /// way the footer does ("Save as New Profile…" included).
    @Test("the sheet's Save wears the footer's label")
    func saveLabelIsTheFooters() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsView.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(!source.isEmpty)
        #expect(
            source.contains(
                "SyncReviewSheet(review:review,"
                    + "saveLabel:model.primarySaveLabel,"
            )
        )
    }
}
