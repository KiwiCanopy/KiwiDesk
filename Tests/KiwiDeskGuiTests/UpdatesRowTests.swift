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
    var canCheckForUpdates: Bool
    private(set) var checks = 0

    init(canCheck: Bool) { canCheckForUpdates = canCheck }
    func checkForUpdates() { checks += 1 }
}

/// The "Check for Updates…" row (#874).
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
@Suite("Check for Updates row (#874)", .serialized)
@MainActor
struct UpdatesRowTests {
    private typealias Row = (
        item: NSMenuItem,
        controller: StatusItemController,
        updater: FakeUpdater
    )

    private func row(canCheck: Bool) -> Row {
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(
            item: FakeStatusItem()
        )
        let updater = FakeUpdater(canCheck: canCheck)
        controller.updater = updater
        return (controller.makeUpdatesItem(), controller, updater)
    }

    /// The click tests below drive the action directly, because
    /// `NSApp` is nil in a test process and `sendAction` traps on
    /// it. So the target/action pair is asserted here instead —
    /// without this, a row wired to nothing would pass every one
    /// of them.
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
        #expect(item.title == "Check for Updates…")
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

    /// The gate that keeps every OTHER suite off the network: in
    /// a test process `Bundle.main` is the runner, which carries
    /// no `SUFeedURL`, so the factory must hand back the inert
    /// updater. If this ever returns a `SparkleUpdater`, every
    /// suite that reaches the factory starts a real scheduled
    /// check — and the first symptom would be Sparkle's own
    /// modal error alert during a test run.
    @Test("the factory is inert outside a configured .app")
    func factoryIsInertInTests() {
        #expect(AppUpdaterFactory.make() is NoUpdater)
    }
}
