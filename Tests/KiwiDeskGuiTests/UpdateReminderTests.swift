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
    var onUpdatePendingChanged: (Bool) -> Void = { _ in }
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
    /// the closure, so the one consumer of the flag is the one
    /// that set it.
    @Test("assigning an updater wires the pending flag to the item")
    func updaterIsWired() {
        let (controller, updater) = controller()
        #expect(!controller.updatePending)
        updater.onUpdatePendingChanged(true)
        #expect(controller.updatePending)
        updater.onUpdatePendingChanged(false)
        #expect(!controller.updatePending)
    }

    @Test("while pending the row reads Update Available… and stays wired")
    func pendingRowReadsUpdateAvailable() {
        let (controller, _) = controller()
        controller.setUpdatePending(true)
        let item = controller.makeUpdatesItem()
        #expect(item.title == "Update Available…")
        #expect(item.isEnabled)
        #expect(item.target === controller)
        #expect(
            item.action
                == #selector(StatusItemController.checkForUpdates(_:))
        )
        controller.setUpdatePending(false)
        #expect(controller.makeUpdatesItem().title == "Check for Updates…")
    }

    /// The row still states its enablement from the updater
    /// (gui.md ▸ every row states `isEnabled`).
    @Test("a pending row is still greyed when the updater refuses")
    func pendingRowFollowsTheUpdater() {
        let (controller, updater) = controller()
        updater.canCheckForUpdates = false
        controller.setUpdatePending(true)
        #expect(!controller.makeUpdatesItem().isEnabled)
    }

    /// The pending row is the same row, so it is in the menu the
    /// app builds.
    @Test("the pending row is in the menu the app builds")
    func pendingRowIsInTheMenu() {
        let (controller, _) = controller()
        controller.setUpdatePending(true)
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        #expect(menu.items.contains { $0.title == "Update Available…" })
    }

    /// The mark names itself: the button's accessibility name and
    /// tooltip say an update is available while one waits, and
    /// stop saying so once it got attention.
    @Test("the status item announces the pending update")
    func markIsAnnounced() throws {
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        controller.setUpdatePending(true)
        #expect(
            button.accessibilityLabel()?.contains("update") == true
        )
        #expect(button.toolTip?.contains("update") == true)
        controller.setUpdatePending(false)
        #expect(
            button.accessibilityLabel()?.contains("update") != true
        )
    }

    /// A permission warning outranks the reminder: the mark never
    /// hides the icon that says window management is paused.
    @Test("the warning icon outranks the update mark")
    func warningOutranksTheMark() throws {
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        controller.setUpdatePending(true)
        controller.setWarning(true)
        #expect(
            button.accessibilityLabel()?.contains("permission") == true
        )
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

    @Test("attention and the session's end withdraw the reminder")
    func attentionWithdraws() {
        let policy = UpdatePromptPolicy()
        var fired: [Bool] = []
        policy.onUpdatePending = { fired.append($0) }
        policy.standardUserDriverDidReceiveUserAttention(
            forUpdate: SUAppcastItem.empty()
        )
        policy.standardUserDriverWillFinishUpdateSession()
        #expect(fired == [false, false])
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
