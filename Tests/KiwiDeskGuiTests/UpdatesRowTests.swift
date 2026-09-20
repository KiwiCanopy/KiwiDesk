import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A status item that draws nothing — the per-file fake idiom,
/// never `NSStatusBar.system`, which `StatusItemSeamGuardTests`
/// seals.
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = NSStatusBarButton()
    var menu: NSMenu?
}

/// An updater that answers what the test tells it to and records
/// whether it was actually asked to check.
@MainActor
private final class FakeUpdater: AppUpdating {
    let updates = UpdateStateStore()
    var canCheckForUpdates: Bool
    private(set) var checks = 0
    var updatePending = false { didSet { onUpdatePendingChanged() } }
    var onUpdatePendingChanged: () -> Void = {}

    init(canCheck: Bool) { canCheckForUpdates = canCheck }
    func checkForUpdates() { checks += 1 }
}

/// The "Update Available…" row (#874, #1536), drawn only while an
/// update was found.
///
/// The seam exists so no suite starts Sparkle's scheduled checks
/// or its XPC services, and a seam nothing injects is a seam
/// nothing proves. `QuickMenuBuilders.checked` already pins that
/// the row STATES its enablement; what it cannot see is whether
/// the statement follows the updater, or whether the click
/// re-reads it — both of which are the point of the row.
///
/// `.serialized` because `LocalizationManager` is process-wide
/// and the row is matched by its English title.
@Suite("Update Available row (#874, #1536)", .serialized)
@MainActor
struct UpdatesRowTests {
    private typealias Row = (
        item: NSMenuItem,
        controller: StatusItemController,
        updater: FakeUpdater
    )

    /// A found update, so the row exists (#1536).
    private func row(canCheck: Bool) -> Row {
        // The click action reads `NSApp`, nil until something
        // touched the shared application: this suite must prove
        // itself alone as well as in a full run (tests.md).
        _ = NSApplication.shared
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(
            item: FakeStatusItem()
        )
        let updater = FakeUpdater(canCheck: canCheck)
        updater.updates.set(.available(version: "9.9.9"))
        controller.updater = updater
        return (controller.makeUpdatesItem()!, controller, updater)
    }

    /// The row says something only when there is something to
    /// say: no found update, no row — asking for a check is the
    /// Settings footer's (#1536).
    @Test("no row while nothing was found")
    func noRowWithoutAFind() {
        _ = NSApplication.shared
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(
            item: FakeStatusItem()
        )
        let updater = FakeUpdater(canCheck: true)
        controller.updater = updater
        for state in [
            UpdateState.unavailable, .notChecked(lastChecked: nil),
            .upToDate(lastChecked: nil), .checking, .failed,
        ] {
            updater.updates.set(state)
            #expect(controller.makeUpdatesItem() == nil)
        }
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        #expect(!menu.items.contains { $0.title == "Update Available…" })
        #expect(!menu.items.contains { $0.title == "Check for Updates…" })
    }

    /// The click tests below drive the action directly rather
    /// than through `sendAction`, so the target/action pair is
    /// asserted here instead — without this, a row wired to
    /// nothing would pass every one of them.
    @Test("the row is wired to the controller's action")
    func rowIsWired() {
        let (item, controller, _) = row(canCheck: true)
        #expect(item.target === controller)
        #expect(
            item.action
                == #selector(StatusItemController.checkForUpdates(_:))
        )
    }

    @Test("the row follows the updater's answer")
    func enablementFollowsTheUpdater() {
        #expect(row(canCheck: true).item.isEnabled)
        #expect(!row(canCheck: false).item.isEnabled)
    }

    /// Not a tautology against the line above: a row that simply
    /// never set `isEnabled` would read as enabled under
    /// `autoenablesItems = false`, so the DISABLED case is the
    /// one carrying the assertion, and the enabled case is what
    /// stops "always false" passing it.
    @Test("a disabled row is disabled because it was stated")
    func disabledIsStatedNotInherited() {
        let (item, _, _) = row(canCheck: false)
        #expect(!item.isEnabled)
        #expect(item.title == "Update Available…")
    }

    @Test("clicking an enabled row asks the updater once")
    func clickChecks() {
        let (item, controller, updater) = row(canCheck: true)
        controller.checkForUpdates(item)
        #expect(updater.checks == 1)
    }

    /// The menu is built on open and can be up while a scheduled
    /// check starts underneath it, so the state the row was built
    /// from is not necessarily the state at click. Reverting that
    /// `guard` sends a check Sparkle has already refused.
    @Test("a click re-reads rather than trusting the row")
    func clickRereadsTheAnswer() {
        let (item, controller, updater) = row(canCheck: true)
        updater.canCheckForUpdates = false
        controller.checkForUpdates(item)
        #expect(updater.checks == 0)
    }

    /// Nothing else pins that the row is actually ADDED. Delete
    /// the `menu.addItem(updates)` line and every other test here
    /// still passes — the item is still constructible — while
    /// "Update Available…" is gone from the app.
    @Test("the row is in the menu the app builds")
    func rowIsInTheMenu() {
        let (_, controller, _) = row(canCheck: true)
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        #expect(
            menu.items.contains {
                $0.title == "Update Available…"
            },
            "the quick menu has no Update Available row"
        )
    }

    /// The gate that keeps every OTHER suite off the network: in
    /// a test process `Bundle.main` is the runner, which carries
    /// no `SUFeedURL`, so the factory must hand back the inert
    /// updater. If this ever returns a `SparkleUpdater`, every
    /// suite that reaches the factory starts a real scheduled
    /// check — and the first symptom would be Sparkle's own
    /// modal error alert during a test run.
    @Test("the factory is inert outside a configured .app")
    func factoryIsInertInTests() {
        // The INPUT is asserted first, and that ordering is the
        // point: `make()` constructs a live updater when the gate
        // admits, so a test that called it to find out would
        // start Sparkle's scheduled channel inside the runner and
        // only then report the failure. Proving the gate cannot
        // admit here makes the call below safe to make.
        #expect(
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL")
                == nil,
            "the test runner carries a Sparkle feed URL"
        )
        #expect(AppUpdaterFactory.make() is NoUpdater)
    }
}
