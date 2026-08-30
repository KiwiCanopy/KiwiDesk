import AppKit
import Sparkle

/// Sparkle UI delegate customizations for accessory app without Dock tile
/// (#1011).
@MainActor
final class UpdatePromptPolicy: NSObject,
    @MainActor SPUStandardUserDriverDelegate
{
    /// Disallows minimizing status window because accessory app lacks Dock
    /// tile (#1011).
    func standardUserDriverAllowsMinimizableStatusWindow() -> Bool {
        false
    }

    /// Activates app for modal alerts.
    func standardUserDriverWillShowModalAlert() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Custom Sparkle user driver ensuring prompts come to front without Dock
/// bouncing (#1011).
@MainActor
final class UpdatePromptDriver: SPUStandardUserDriver {
    /// Restores app activation when download starts (#1011).
    override func showDownloadInitiated(
        cancellation: @escaping () -> Void
    ) {
        super.showDownloadInitiated(cancellation: cancellation)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Brings app to front before presenting install-and-restart prompt
    /// (#1011).
    override func showReadyToInstallAndRelaunch() async
        -> SPUUserUpdateChoice
    {
        NSApp.activate(ignoringOtherApps: true)
        return await super.showReadyToInstallAndRelaunch()
    }
}
