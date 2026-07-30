import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// A durable discovery step before the closing choices. Unlike
    /// the old timed menu-bar popover, this remains visible when the
    /// user auto-hides the menu bar and offers the real action.
    var discoverShortcuts: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(
                L(
                    "keybinding.show_shortcuts",
                    "Show shortcuts panel"
                )
            )
            .font(.title.bold())
            Text(
                L(
                    "onboarding.discovery.body",
                    "Press %1$@ anytime to see an overview of all "
                        + "your shortcuts.",
                    model.shortcutGlyphs()
                )
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            Spacer()
            Button(L("menu.view_shortcuts", "View Shortcuts…")) {
                model.onShowShortcuts()
            }
            .controlSize(.large)
            Button(L("onboarding.continue", "Continue")) {
                model.step = .readyToExplore
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
    }
}
