import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The orange mark's third pending fact, sync stopped (#3088):
/// a fake sync status drives the icon, its two announced channels
/// and the Sync Paused… row. `.serialized`: titles are matched in
/// English through the process-wide `LocalizationManager`.
@Suite("Sync stopped mark (#3088)", .serialized)
@MainActor
struct SyncStoppedMarkTests {
    private static let newer = NewerFormatOnDisk(
        artifact: .guiConfig,
        format: 999
    )

    private func controller() -> (StatusItemController, FakeSyncUpdater) {
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(item: RowFakeStatusItem())
        let updater = FakeSyncUpdater()
        controller.updater = updater
        return (controller, updater)
    }

    private func marked(_ controller: StatusItemController) throws -> Bool {
        let button = try #require(controller.anchorButton)
        return try #require(button.image)
            is StatusItemController.UpdateMarkImage
    }

    /// Every case named, so a new `SyncStatus` case is a compile
    /// error in `stopsSync` before it is a silent false here.
    @Test("only a newer folder and a two-sided change stop sync")
    func predicate() {
        let stops: [(SyncStatus, Bool)] = [
            (.off, false),
            (.upToDate, false),
            (.folderUnavailable, false),
            (.changedOnBoth, true),
            (.conflictCopy("a/b"), false),
            (.newerOnAnotherMac(Self.newer), true),
            (.newerHere(Self.newer), false),
        ]
        for (status, expected) in stops {
            #expect(
                StatusItemController.stopsSync(status) == expected,
                "\(status)"
            )
        }
    }

    @Test("a stopped sync marks the icon on both channels and clears")
    func markFollowsTheStatus() throws {
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        #expect(try !marked(controller))
        controller.setSyncStatus(.newerOnAnotherMac(Self.newer))
        #expect(try marked(controller))
        #expect(button.accessibilityLabel() == "KiwiDesk (sync paused)")
        #expect(button.toolTip?.contains("Sync across Macs") == true)
        controller.setSyncStatus(.upToDate)
        #expect(try !marked(controller))
        #expect(button.accessibilityLabel() == "KiwiDesk")
        controller.setSyncStatus(.changedOnBoth)
        #expect(try marked(controller))
    }

    @Test("the Sync Paused… row exists only while sync is stopped")
    func rowFollowsTheStatus() throws {
        let (controller, _) = controller()
        #expect(controller.makeSyncPausedItem() == nil)
        controller.setSyncStatus(.conflictCopy("x"))
        #expect(controller.makeSyncPausedItem() == nil)
        controller.setSyncStatus(.changedOnBoth)
        let row = try #require(controller.makeSyncPausedItem())
        #expect(row.title == "Sync Paused…")
        #expect(row.isEnabled)
        #expect(row.target === controller)
        var shown = 0
        controller.onShowSyncStatus = { shown += 1 }
        controller.showSyncStatus(row)
        #expect(shown == 1)
    }

    /// Owner ruling 2026-11-08: both rows show, and the update
    /// offer's words win the mark.
    @Test("an update offer outranks the mark's words, both rows show")
    func updateOutranksAndBothRowsShow() throws {
        let (controller, updater) = controller()
        let button = try #require(controller.anchorButton)
        controller.setSyncStatus(.newerOnAnotherMac(Self.newer))
        updater.updatePending = true
        #expect(button.accessibilityLabel() == "KiwiDesk (update available)")
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        let titles = menu.items.map(\.title)
        #expect(titles.contains("Sync Paused…"))
        #expect(titles.contains("Update Available…"))
        updater.updatePending = false
        #expect(button.accessibilityLabel() == "KiwiDesk (sync paused)")
    }

    @Test("a stopped sync outranks What's new on the mark's words")
    func outranksWhatsNew() async throws {
        LocalizationManager.shared.select("en")
        let (coordinator, _, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        let controller = StatusItemController(item: RowFakeStatusItem())
        controller.updater = WhatsNewFakeUpdater(whatsNew: coordinator)
        let button = try #require(controller.anchorButton)
        await coordinator.launched(opensWindow: false, existingUser: true)
        controller.setSyncStatus(.changedOnBoth)
        #expect(button.accessibilityLabel() == "KiwiDesk (sync paused)")
        controller.setSyncStatus(.upToDate)
        #expect(
            button.accessibilityLabel()
                == "KiwiDesk (what's new in 9999.2.0)"
        )
    }

    /// The row lands where a search for the setting lands, so
    /// the anchor names a control the row draws.
    @Test("the landing is the search's own landing for the row")
    func landingMatchesTheSearch() throws {
        let row = try #require(
            SettingsSearchIndex.rows().first {
                $0.key == .general(.syncFolder)
            }
        )
        #expect(row.anchor == .syncAcrossMacs)
        #expect(SettingsAnchor.syncAcrossMacs.anchor != nil)
    }

    /// Like the other offers it rides only the healthy icons: a
    /// permission warning and a config error keep their own glyph
    /// and name (#3088 ruling ▸ 1).
    @Test("a warning and a config error outrank the mark")
    func brokenStatesOutrank() throws {
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        controller.setSyncStatus(.changedOnBoth)
        controller.setWarning(true)
        #expect(try !marked(controller))
        #expect(
            button.accessibilityLabel()?.contains("permission") == true
        )
        controller.setWarning(false)
        controller.setConfigError(true)
        #expect(try !marked(controller))
        #expect(button.accessibilityLabel()?.contains("config") == true)
        controller.setConfigError(false)
        #expect(try marked(controller))
    }
}

@MainActor
private final class FakeSyncUpdater: AppUpdating {
    let autoInstall = AutoInstallSetting.inert()
    var whatsNew: WhatsNewCoordinator? { nil }
    let updates = UpdateStateStore()
    var canCheckForUpdates = true
    var updatePending = false { didSet { onUpdatePendingChanged() } }
    var onUpdatePendingChanged: () -> Void = {}
    var onWillRelaunch: () -> Void = {}
    func checkForUpdates() {}
}

/// The app's two doors into the fact, pinned by spelling: the
/// sync status reaches the status item, and the row lands
/// Settings on the Sync across Macs row. A legal rename reds
/// these; read a red as "the wiring stopped saying it".
@Suite("Sync stopped wiring (#3088)")
struct SyncStoppedWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: root.appendingPathComponent(path)
        )
    }

    @Test("the sync status reaches the status item")
    func statusReachesTheItem() throws {
        let text = try Self.source("Sources/KiwiDesk/AppDelegate.swift")
        let body = try #require(
            SourceScan.declarationBody(
                after: "core.sync.onStatusChange =",
                in: text
            )
        )
        #expect(body.contains("statusItem?.setSyncStatus(status)"))
        let row = try #require(
            SourceScan.declarationBody(
                after: "statusItem.onShowSyncStatus =",
                in: text
            )
        )
        #expect(row.contains("dashboard.showSyncAcrossMacs()"))
    }

    @Test("the row lands on the anchored Sync across Macs row")
    func rowLandsOnTheAnchor() throws {
        let window = try Self.source(
            "Sources/KiwiDesk/Settings/SettingsWindowController.swift"
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func showSyncAcrossMacs()",
                in: window
            )
        )
        #expect(body.contains("model.land(on: .syncAcrossMacs)"))
        let row = try Self.source(
            "Sources/KiwiDesk/Settings/Components/General/"
                + "SyncAcrossMacsRow.swift"
        )
        #expect(
            row.contains(
                ".searchAnchored(SettingsCatalog.general.syncAcrossMacs)"
            )
        )
    }
}
