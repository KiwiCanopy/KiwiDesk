import AppKit
import Sparkle
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A status item carrying a REAL button so the mark is
/// observable; never `NSStatusBar.system`, which
/// `StatusItemSeamGuardTests` seals.
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = NSStatusBarButton()
    var menu: NSMenu?
}

@MainActor
private final class FakeUpdater: AppUpdating {
    var canCheckForUpdates = true
    private(set) var checks = 0
    var updatePending = false { didSet { onUpdatePendingChanged() } }
    var onUpdatePendingChanged: () -> Void = {}
    func checkForUpdates() { checks += 1 }
}

/// The gentle scheduled-update reminder (#1013): a background
/// app's scheduled alert is drawn behind every window, so while
/// one waits the status item carries a mark and the updates row
/// reads "Update Available…"; acting on the row takes the same
/// door a fresh check takes, which Sparkle answers by bringing
/// the waiting alert forward. `.serialized`: titles are matched
/// in English through the process-wide `LocalizationManager`.
@Suite("Gentle update reminder (#1013)", .serialized)
@MainActor
struct UpdateReminderTests {
    private func controller() -> (StatusItemController, FakeUpdater) {
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(item: FakeStatusItem())
        let updater = FakeUpdater()
        controller.updater = updater
        return (controller, updater)
    }

    /// The controller wires itself: assigning an updater hands it
    /// the nudge, and the item re-renders off the updater's fact.
    @Test("assigning an updater wires the nudge to a render")
    func updaterIsWired() throws {
        let (controller, updater) = controller()
        let button = try #require(controller.anchorButton)
        #expect(!controller.updatePending)
        updater.updatePending = true
        #expect(controller.updatePending)
        #expect(
            button.image is StatusItemController.UpdateMarkImage
        )
        updater.updatePending = false
        #expect(
            !(try #require(button.image)
                is StatusItemController.UpdateMarkImage)
        )
    }

    @Test("while pending the row reads Update Available… and stays wired")
    func pendingRowReadsUpdateAvailable() {
        let (controller, updater) = controller()
        updater.updatePending = true
        let item = controller.makeUpdatesItem()
        #expect(item.title == "Update Available…")
        #expect(item.isEnabled)
        #expect(item.target === controller)
        #expect(
            item.action
                == #selector(StatusItemController.checkForUpdates(_:))
        )
        updater.updatePending = false
        #expect(controller.makeUpdatesItem().title == "Check for Updates…")
    }

    /// The row still states its enablement from the updater
    /// (gui.md ▸ every row states `isEnabled`).
    @Test("a pending row is still greyed when the updater refuses")
    func pendingRowFollowsTheUpdater() {
        let (controller, updater) = controller()
        updater.canCheckForUpdates = false
        updater.updatePending = true
        #expect(!controller.makeUpdatesItem().isEnabled)
    }

    /// The pending row is the same row, so it is in the menu the
    /// app builds.
    @Test("the pending row is in the menu the app builds")
    func pendingRowIsInTheMenu() {
        let (controller, updater) = controller()
        updater.updatePending = true
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        #expect(menu.items.contains { $0.title == "Update Available…" })
    }

    /// The mark names itself: the button's accessibility name and
    /// tooltip say an update is available while one waits, and
    /// stop saying so once it got attention.
    @Test("the status item announces the pending update")
    func markIsAnnounced() throws {
        let (controller, updater) = controller()
        let button = try #require(controller.anchorButton)
        updater.updatePending = true
        #expect(
            button.accessibilityLabel()?.contains("update") == true
        )
        #expect(button.toolTip?.contains("update") == true)
        updater.updatePending = false
        #expect(
            button.accessibilityLabel()?.contains("update") != true
        )
    }

    /// A warning, the starting phase and a config error outrank
    /// the reminder on BOTH channels: the icon that says something
    /// is wrong carries no dot and keeps its own name. Each
    /// negative clause REQUIRES an image, or the title-fallback
    /// path would satisfy it with nil.
    @Test("the broken and starting states outrank the mark on both channels")
    func brokenStatesOutrankTheMark() throws {
        let (controller, updater) = controller()
        let button = try #require(controller.anchorButton)
        updater.updatePending = true
        controller.setWarning(true)
        #expect(
            button.accessibilityLabel()?.contains("permission") == true
        )
        #expect(
            !(try #require(button.image)
                is StatusItemController.UpdateMarkImage)
        )
        controller.setWarning(false)
        controller.setBootPhase(.scanning(scanned: 1, total: 2))
        #expect(
            !(try #require(button.image)
                is StatusItemController.UpdateMarkImage)
        )
        #expect(
            button.accessibilityLabel()?.contains("starting") == true
        )
        controller.setBootPhase(.ready)
        controller.setConfigError(true)
        #expect(
            !(try #require(button.image)
                is StatusItemController.UpdateMarkImage)
        )
        #expect(
            button.accessibilityLabel()?.contains("config") == true
        )
        controller.setConfigError(false)
        #expect(
            button.image is StatusItemController.UpdateMarkImage
        )
    }

    /// A mode icon that is no SF Symbol takes the title fallback
    /// and has no image to badge: the announced channels still
    /// carry the reminder (#937's shape — a stand-down asks whether
    /// either channel is reached, never one alone).
    @Test("without an image the reminder is still announced")
    func announcedWithoutAnImage() throws {
        let (controller, updater) = controller()
        let button = try #require(controller.anchorButton)
        controller.setModeIcon("no.such.symbol.kiwidesk")
        updater.updatePending = true
        #expect(button.image == nil)
        #expect(
            button.accessibilityLabel()?.contains("update") == true
        )
        #expect(button.toolTip?.contains("update") == true)
    }
}

/// The one-home obligation no behavior test can hold: a cached
/// copy kept in sync by the nudge passes every render assertion,
/// so the controller's READ is pinned by spelling — a computed
/// property over the updater, and no stored copy anywhere in the
/// file (gui.md).
@Suite("The pending fact is read, never stored (#1013)")
struct UpdateReminderReadNotStoredTests {
    @Test("the controller reads the updater's fact at render")
    func controllerReadsNotStores() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/StatusItemController.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        try #require(!source.isEmpty)
        #expect(
            source.contains(
                "var updatePending: Bool { updater.updatePending }"
            )
        )
        #expect(!source.contains("updatePending ="))
        #expect(!source.contains("var updatePending = "))
    }
}

/// What the policy DECLARES for gentle reminders (#1013): the
/// four answers Sparkle looks up by selector, asserted by CALLING
/// the pure ones and by the ObjC runtime for the rest — a
/// near-miss on an optional requirement compiles and silently
/// stops conforming.
@Suite("Gentle reminder policy (#1013)")
@MainActor
struct UpdateReminderPolicyTests {
    /// Both focus proposals are declined: an unsolicited offer
    /// never takes the screen, whatever Sparkle proposes.
    @Test("the policy supports gentle reminders and shows no scheduled alert")
    func policyDeclaresGentleReminders() {
        let policy = UpdatePromptPolicy()
        #expect(policy.supportsGentleScheduledUpdateReminders)
        let item = SUAppcastItem.empty()
        for focus in [true, false] {
            #expect(
                !policy.standardUserDriverShouldHandleShowingScheduledUpdate(
                    item,
                    andInImmediateFocus: focus
                ),
                "\(focus)"
            )
        }
    }

    /// The fact lives on the policy: attention and the session's
    /// end clear it, and every change nudges the consumer once.
    @Test("attention and the session's end withdraw the reminder")
    func attentionWithdraws() {
        let policy = UpdatePromptPolicy()
        var nudges = 0
        policy.onUpdatePendingChanged = { nudges += 1 }
        policy.updatePending = true
        #expect(nudges == 1)
        policy.standardUserDriverDidReceiveUserAttention(
            forUpdate: SUAppcastItem.empty()
        )
        #expect(!policy.updatePending)
        #expect(nudges == 2)
        policy.updatePending = true
        policy.standardUserDriverWillFinishUpdateSession()
        #expect(!policy.updatePending)
        #expect(nudges == 4)
        // Every write nudges — a same-value write too, since a
        // redundant render is idempotent and a gate would be one
        // more thing to pin.
        policy.updatePending = false
        #expect(nudges == 5)
    }

    @Test("Sparkle can find every reminder answer by selector")
    func selectorsResolve() {
        let policy = UpdatePromptPolicy()
        for selector in [
            #selector(
                getter: SPUStandardUserDriverDelegate
                    .supportsGentleScheduledUpdateReminders
            ),
            #selector(
                SPUStandardUserDriverDelegate
                    .standardUserDriverShouldHandleShowingScheduledUpdate(
                        _:
                        andInImmediateFocus:
                    )
            ),
            #selector(
                SPUStandardUserDriverDelegate
                    .standardUserDriverWillHandleShowingUpdate(
                        _:
                        forUpdate:
                        state:
                    )
            ),
            #selector(
                SPUStandardUserDriverDelegate
                    .standardUserDriverDidReceiveUserAttention(forUpdate:)
            ),
            #selector(
                SPUStandardUserDriverDelegate
                    .standardUserDriverWillFinishUpdateSession
            ),
        ] {
            #expect(policy.responds(to: selector), "\(selector)")
        }
    }
}
