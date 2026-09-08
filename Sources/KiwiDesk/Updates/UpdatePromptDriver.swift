import AppKit
import Sparkle

/// Sparkle UI delegate customizations for an accessory app with no
/// Dock tile (#1011). Held for the process lifetime by
/// `SparkleUpdater`: the standard driver references its delegate
/// WEAKLY, so a policy nobody retains is a policy Sparkle stops
/// asking.
@MainActor
final class UpdatePromptPolicy: NSObject,
    @MainActor SPUStandardUserDriverDelegate
{
    /// A SCHEDULED update waiting behind the gentle reminder
    /// (#1013): set when Sparkle leaves the showing to KiwiDesk,
    /// cleared once the update got attention or the session ended.
    /// The one home of the fact; `onUpdatePendingChanged` nudges
    /// the consumer, which reads it back.
    var updatePending = false {
        didSet { onUpdatePendingChanged() }
    }
    var onUpdatePendingChanged: () -> Void = {}

    /// Gentle reminders (#1013): a background app's scheduled
    /// alert is drawn BEHIND every window, which for a menu-bar
    /// app is drawn nowhere. Sparkle's own warning names this.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// A scheduled update is KiwiDesk's to show whatever focus
    /// Sparkle proposes: an unsolicited offer never takes the
    /// screen (#1013; #1011 is the opposite rule). User-initiated
    /// checks never reach this answer.
    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        updatePending = !handleShowingUpdate
    }

    func standardUserDriverDidReceiveUserAttention(
        forUpdate update: SUAppcastItem
    ) {
        updatePending = false
    }

    func standardUserDriverWillFinishUpdateSession() {
        updatePending = false
    }

    /// Disallows minimizing the status window (#1011): activating
    /// a process deminiaturizes nothing, so a parked prompt would
    /// sit in a Dock KiwiDesk has no icon in — refusing the
    /// affordance is what closes the parking route, and only that.
    func standardUserDriverAllowsMinimizableStatusWindow() -> Bool {
        false
    }

    /// Activates app for modal alerts — unconditional only because
    /// Sparkle gates them on user engagement
    /// (`SPUScheduledUpdateDriver.m`, Sparkle 2.9.6); check that
    /// gate when the version moves.
    func standardUserDriverWillShowModalAlert() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Custom Sparkle user driver ensuring prompts come to front without Dock
/// bouncing (#1011).
@MainActor
final class UpdatePromptDriver: SPUStandardUserDriver {
    /// Restores app activation when the download starts (#1011):
    /// the Install click closes Sparkle's alert BEFORE the
    /// completion block runs, deactivating a now window-less
    /// accessory app. After `super`, so the status window exists
    /// when the app is raised.
    override func showDownloadInitiated(
        cancellation: @escaping () -> Void
    ) {
        super.showDownloadInitiated(cancellation: cancellation)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Brings app to front before the install-and-restart prompt
    /// (#1011). Depends on `UpdatePromptPolicy` refusing the
    /// minimize button — a parked window is the one state
    /// activation cannot recover.
    override func showReadyToInstallAndRelaunch() async
        -> SPUUserUpdateChoice
    {
        NSApp.activate(ignoringOtherApps: true)
        return await super.showReadyToInstallAndRelaunch()
    }
}
