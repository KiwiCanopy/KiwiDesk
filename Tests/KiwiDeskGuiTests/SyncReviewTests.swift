import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The sheet at Save (#2450): every setting both Macs changed is
/// one row, a gap group folded while the draft's edges agree, each
/// row picked on purpose before Save may run. Main-actor cost: one
/// test core and model per test, no scans. Locale pinned per body
/// (#740).
@Suite("The sync sheet at Save", .serialized)
@MainActor
struct SyncReviewTests {
    private let change = SyncedChange(paths: ["gui.json"], mac: "Studio")

    private func setup() throws -> (KiwiCore, SettingsModel) {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-sync-review-\(UUID())")
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

    /// The other Mac's settings write: the draft's settings are
    /// read from the live profile, as `SyncAdoptTests`' pair case
    /// does.
    private func theirSettings(
        _ core: KiwiCore,
        _ edit: (inout TilingSettings) -> Void
    ) {
        edit(&core.tiler.settings)
    }

    private func outer(_ v: CGFloat) -> Gaps.Outer {
        .init(top: v, bottom: v, left: v, right: v)
    }

    @Test("an Outer gap edit both Macs made is one row")
    func outerIsOneRow() throws {
        LocalizationManager.shared.select("en")
        let (core, model) = try setup()
        model.config.settings.gapsGlobal.outer = outer(12)
        theirSettings(core) { $0.gapsGlobal.outer = self.outer(4) }
        model.adoptSyncedChange(change)
        #expect(model.sync.conflicts.count == 4)
        #expect(model.reviewSyncConflicts())
        let review = try #require(model.sync.review)
        let row = try #require(review.rows.first)
        #expect(review.rows.count == 1, "\(review.rows.map(\.id))")
        #expect(row.key == .gaps(.outer))
        #expect(row.yours == "12 pt")
        #expect(row.theirs == "4 pt")
        #expect(review.mac == "Studio")
    }

    @Test("a mixed other side lists its edges")
    func mixedTheirsListsEdges() throws {
        LocalizationManager.shared.select("en")
        let (core, model) = try setup()
        model.config.settings.gapsGlobal.outer = outer(12)
        theirSettings(core) { $0.gapsGlobal.outer.left = 4 }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        let row = try #require(model.sync.review?.rows.first)
        #expect(row.key == .gaps(.outer))
        #expect(row.theirs.hasPrefix("mixed ("), "\(row.theirs)")
        #expect(row.theirs.contains("Left: 4 pt"), "\(row.theirs)")
    }

    @Test("edges the draft set apart are a row each")
    func mixedYoursListsApart() throws {
        let (core, model) = try setup()
        model.config.settings.gapsGlobal.outer.top = 20
        model.config.settings.gapsGlobal.outer.left = 30
        theirSettings(core) {
            $0.gapsGlobal.outer.top = 2
            $0.gapsGlobal.outer.left = 3
        }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        #expect(
            model.sync.review?.rows.map(\.key)
                == [.gaps(.outerTop), .gaps(.outerLeft)]
        )
    }

    @Test("Theirs on a folded row moves every edge")
    func theirsMovesTheGroup() throws {
        let (core, model) = try setup()
        model.config.settings.gapsGlobal.outer = outer(12)
        theirSettings(core) { $0.gapsGlobal.outer.left = 4 }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        model.answerSyncReview([SettingKey.gaps(.outer).id: .theirs])
        #expect(
            model.config.settings.gapsGlobal.outer
                == model.cleanConfig.settings.gapsGlobal.outer
        )
        #expect(model.config.settings.gapsGlobal.outer.left == 4)
        #expect(model.sync.conflicts.isEmpty)
        #expect(model.sync.review == nil)
    }

    @Test("Cancel saves nothing and keeps the conflicts")
    func cancelKeepsConflicts() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        model.performPrimarySave()
        #expect(model.sync.review != nil)
        model.cancelSyncReview()
        #expect(model.sync.review == nil)
        #expect(model.sync.conflicts.map(\.key) == [.shortcuts(.modeCycle)])
        #expect(model.isDirty)
    }

    @Test("Save waits until every row is picked")
    func saveNeedsEveryPick() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        model.config.settings.gapsGlobal.outer = outer(12)
        theirSettings(core) { $0.gapsGlobal.outer = self.outer(4) }
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        let review = try #require(model.sync.review)
        #expect(review.rows.count == 2)
        #expect(!SyncReviewSheet.allPicked(review, [:]))
        #expect(
            !SyncReviewSheet.allPicked(
                review,
                [SettingKey.gaps(.outer).id: .yours]
            )
        )
        #expect(
            SyncReviewSheet.allPicked(
                review,
                [
                    SettingKey.gaps(.outer).id: .yours,
                    SettingKey.shortcuts(.modeCycle).id: .theirs,
                ]
            )
        )
    }

    @Test("the summary counts what took no question")
    func summaryCounts() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        model.config.spaceHistory = .allScreens
        theirSettings(core) { $0.gapsGlobal.outer = self.outer(3) }
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.reviewSyncConflicts())
        let review = try #require(model.sync.review)
        // Their outer gap folds to one change taken in; the draft's
        // space history saves as it is.
        #expect(review.taken == 1)
        #expect(review.yourOthers == 1)
    }

    @Test("an unpicked row says so to VoiceOver")
    func unpickedIsSpoken() throws {
        LocalizationManager.shared.select("en")
        let row = SyncReview.Row(
            key: .gaps(.outer),
            label: "Outer gap",
            yours: "12 pt",
            theirs: "4 pt"
        )
        #expect(SyncText.spokenPick(nil, row: row) == "Not picked")
        #expect(SyncText.spokenPick(.theirs, row: row) == "Theirs, 4 pt")
    }
}
