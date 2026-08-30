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
            ZStack {
                ClickAwayResignsFocus()
                content()
            }
            .environment(
                \.settingsModeReveal,
                model.modeRevealActive
            )
            .overlay(alignment: .bottomTrailing) {
                showPreviewOffer(width)
            }
            // Save pill floats over content when undocked (#678, owner ruling
            // 2026-08-09).
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
