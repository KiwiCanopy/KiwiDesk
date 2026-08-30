import KiwiDeskCore
import SwiftUI

/// Settings window shell chrome: header, banners, content, and save surface
/// (#678, 17a).
extension SettingsView {

    /// Shared chrome wrapper for detail and raw config editor.
    @ViewBuilder func chrome(
        _ width: SettingsWidthClass,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            SettingsHeaderBar(model: model)
                // Lift header z-index so search dropdown paints over content.
                .zIndex(1)
            // The paused banner outranks the per-section Lua one:
            // missing Accessibility makes the whole dashboard
            // inert. Gated here (not self-gating) so the padding
            // never reserves empty space when trusted.
            if model.permissionPaused {
                PermissionPausedBanner(
                    onResolve: model.onResolvePermission
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }
            if let notice = model.searchModeNotice {
                SettingsSearchNotice(text: notice)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }
            // `ClickAwayResignsFocus` installs a window-scoped
            // mouse-down monitor (#93) committing an edited field
            // when a click lands outside it — a zero-size,
            // hit-test-transparent probe.
            ZStack {
                ClickAwayResignsFocus()
                content()
            }
            // Above BOTH panes on purpose (#760): the segment is
            // always in the header, so a flip can wash Home's
            // inserted cards or an in-area surface alike — one
            // mount, the model owns the timeline.
            .environment(
                \.settingsModeReveal,
                model.modeRevealActive
            )
            .overlay(alignment: .bottomTrailing) {
                showPreviewOffer(width)
            }
            // Save pill floats over content when undocked (#678, owner ruling
            // 2026-08-09).
            // The overlay is EMPTY below the row breakpoint
            // rather than conditionally applied, so the content
            // subtree's identity survives the crossing.
            .overlay(alignment: .bottom) {
                if !width.docksSavePill {
                    SettingsFooter(model: model)
                        .padding(.bottom, 22)
                        .offset(
                            x: panelDocked(width)
                                ? -SettingsTheme.panelWidth / 2
                                : 0
                        )
                }
            }
            // Detached preview overlays above save pill (code review
            // 2026-08-11).
            .overlay(alignment: .topTrailing) {
                detachedPreview(width)
            }
            // Docks save pill as sibling footer on narrow width classes (17a).
            if width.docksSavePill {
                SettingsFooter(model: model, docked: true)
            }
        }
        .background(SettingsTheme.page)
        .ignoresSafeArea(.container, edges: .top)
    }
}
