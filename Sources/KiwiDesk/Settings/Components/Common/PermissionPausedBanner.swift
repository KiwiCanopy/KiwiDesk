import KiwiDeskCore
import SwiftUI

/// A non-dismissible banner shown across the whole dashboard
/// whenever macOS Accessibility permission is missing: window
/// management is fully paused, so every tiling control below is
/// silently inert. Unlike the keybinding-conflict nudge this
/// tracks a persistent fact — there is no dismiss (hiding "nothing
/// works" while it's still true would be a grey-don't-hide
/// violation).
///
/// The rows below stay EDITABLE while it shows, which is the
/// whole reason the banner says "paused" rather than greying the
/// dashboard out: a setup prepared before the grant lands is
/// waiting the moment it does. That is also why the banner is the
/// only thing on screen that changes — greying every control
/// would say the app is broken, when what is true is that one
/// switch is off.
struct PermissionPausedBanner: View {
    /// The "Open System Settings" action — the macOS pane
    /// directly, not the tour's grant step (#678 Phase 4 pass 9;
    /// `AppDelegate`'s wiring carries why the two routes differ).
    /// Passed directly rather than through the model: this view
    /// has no reactive state of its own — visibility is gated
    /// externally in `chrome()` by `model.permissionPaused`.
    let onResolve: () -> Void

    var body: some View {
        // Center-aligned, not `.top`: the message is a single
        // line and the action button is taller than it, so a
        // top alignment leaves the icon + text hugging the top
        // while the button sits centered (the
        // KeybindingConflictBanner uses `.top` only because its
        // text can wrap to several lines).
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.warningInk)
            Text(
                L(
                    "settings.permission_paused",
                    "Window management is paused — KiwiDesk "
                        + "needs Accessibility permission."
                )
            )
            .font(.callout)
            .foregroundStyle(SettingsTheme.warningInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(
                L(
                    "settings.permission_paused.action",
                    "Open System Settings"
                )
            ) {
                onResolve()
            }
            .settingsActionButton()
        }
        .padding(12)
        // A solid warning surface, not `.orange.opacity(0.12)`:
        // an opacity wash takes its result from whatever is
        // behind it, so the bar drifted with the page and could
        // not be given a dark counterpart at all. The pair also
        // holds 4.5:1 for `warningInk` on it, which a wash over an
        // unknown backdrop cannot promise.
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.warningSurface)
        )
    }
}
