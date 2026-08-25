import AppKit
import Sparkle

/// What Sparkle's stock UI must do differently for an app with
/// no Dock tile (#1011). Separate from the driver below only
/// because Sparkle captures a user driver's delegate in its
/// initializer, so the driver cannot be its own.
///
/// Held for the process lifetime by `SparkleUpdater`: the
/// standard driver references its delegate WEAKLY, so a policy
/// nobody retains is a policy Sparkle stops asking.
/// The conformance is isolated rather than `nonisolated` +
/// `assumeIsolated`: Sparkle calls every user-driver method from
/// the main thread and asserts on it, so the isolation is the
/// truth rather than a promise this file makes.
@MainActor
final class UpdatePromptPolicy: NSObject,
    @MainActor SPUStandardUserDriverDelegate
{
    /// Refuse the minimize button on the status window.
    ///
    /// Sparkle offers it because a regular app update is usually
    /// quick, and parking the progress window is reasonable when
    /// a Dock tile can bring it back. Here it cannot: the window
    /// the user parked during the download is the same one that
    /// becomes the install-and-restart prompt, and activating a
    /// process does not deminiaturize anything — so a minimized
    /// prompt would sit in a Dock KiwiDesk has no icon in.
    /// Refusing the affordance is what keeps the driver's
    /// activation below sufficient on its own.
    func standardUserDriverAllowsMinimizableStatusWindow() -> Bool {
        false
    }

    /// Come forward for Sparkle's modal alerts too — an updater
    /// error, or the acknowledgement after an install. Each is a
    /// window the user must answer, and `.accessory` puts none of
    /// them in front by itself.
    func standardUserDriverWillShowModalAlert() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Sparkle's stock user driver plus one thing: the prompt that
/// asks to install and restart brings KiwiDesk to the front
/// before it appears (#1011).
///
/// **Why a subclass, when the seam next door is a delegate.**
/// Sparkle activates the app itself for the windows it opens on
/// a check the USER asked for — the update alert, the permission
/// prompt — and `StatusItemController+Updates` activates once
/// more before that check, so the window a user asked for is in
/// front. (A SCHEDULED check is deliberately gentler and stays
/// behind; `docs/design-decisions.md` ▸ *Permanent accessory
/// mode* scopes what this rule does and does not promise.) The
/// install-and-restart prompt is not another window: it is a
/// later state of the status window the DOWNLOAD opened, and
/// Sparkle announces it with `NSApp.requestUserAttention`,
/// which bounces a Dock icon. KiwiDesk has none
/// (`docs/design-decisions.md` ▸ *Permanent accessory mode*),
/// so on the ordinary path — start the download, go back to
/// work while it runs — the app is no longer active when the
/// prompt arrives and the prompt is behind everything the user
/// has open, with nothing saying the update is waiting.
///
/// Neither `SPUUpdaterDelegate` nor
/// `SPUStandardUserDriverDelegate` carries a hook at that
/// moment: the user-driver delegate's alert hooks fire for
/// modal `NSAlert`s, which this is not, and the updater
/// delegate's nearest neighbour (`didExtractUpdate`) fires
/// before the installer has finished preparing. Overriding
/// `showReadyToInstallAndRelaunch` is the only seam that names
/// the moment rather than approximating it.
@MainActor
final class UpdatePromptDriver: SPUStandardUserDriver {
    /// Come forward, then let Sparkle put up the prompt.
    ///
    /// Unconditional rather than gated on `!NSApp.isActive`:
    /// activating an already-active app does nothing, so the
    /// branch would only add a second thing to keep true.
    ///
    /// The two statements are not ordered against each other and
    /// the guard does not pin an order: `super` shows the window
    /// synchronously, so both land in one main-actor stretch
    /// before anything redraws. What the activation depends on is
    /// `UpdatePromptPolicy` refusing the minimize button — a
    /// parked window is the one state activation cannot recover.
    override func showReadyToInstallAndRelaunch() async
        -> SPUUserUpdateChoice
    {
        NSApp.activate(ignoringOtherApps: true)
        return await super.showReadyToInstallAndRelaunch()
    }
}
