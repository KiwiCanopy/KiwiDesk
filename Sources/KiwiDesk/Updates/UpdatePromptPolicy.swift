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

    /// KiwiDesk's own window got an offer (#1542): the same answer
    /// as above — a scheduled one waits behind the mark, a user's
    /// own check shows now. True when it shows.
    func offerArrived(userInitiated: Bool) -> Bool {
        updatePending = !userInitiated
        return userInitiated
    }

    /// The own window's offer is on screen.
    func offerGotAttention() {
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
    /// gate when the version moves. Forcing rather than cooperative
    /// (#1170): Sparkle calls this off any user event of ours.
    func standardUserDriverWillShowModalAlert() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
