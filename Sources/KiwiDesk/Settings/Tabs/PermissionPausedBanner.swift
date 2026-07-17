import KiwiDeskCore
import SwiftUI

/// A non-dismissible banner shown across the whole dashboard
/// whenever macOS Accessibility permission is missing: window
/// management is fully paused, so every tiling control below is
/// silently inert. Unlike the keybinding-conflict nudge this
/// tracks a persistent fact — there is no dismiss (hiding "nothing
/// works" while it's still true would be a grey-don't-hide
/// violation), and the "Enable Accessibility…" button routes to
/// the same onboarding grant step as the quick-menu warning row.
struct PermissionPausedBanner: View {
    /// The "Enable Accessibility…" action. Passed directly rather
    /// than through the model: this view has no reactive state of
    /// its own — visibility is gated externally in `chrome()` by
    /// `model.permissionPaused`.
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
                .foregroundStyle(.orange)
            Text(
                L(
                    "settings.permission_paused",
                    "Window management is paused — KiwiDesk "
                        + "needs Accessibility permission."
                )
            )
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(
                L(
                    "settings.permission_paused.action",
                    "Enable Accessibility…"
                )
            ) {
                onResolve()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.12))
        )
    }
}
