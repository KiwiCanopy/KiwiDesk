import KiwiDeskCore
import SwiftUI

/// Responsive preview presentation logic for `SettingsView`
/// (#678 turn 17a).
extension SettingsView {
    /// Evaluates preview form for window width class.
    func previewForm(
        _ width: SettingsWidthClass
    ) -> SettingsPreviewForm? {
        guard panelOffered else { return nil }
        return SettingsPreviewForm.at(width, shown: previewShown)
    }

    /// Whether preview panel is docked in layout column.
    func panelDocked(_ width: SettingsWidthClass) -> Bool {
        previewForm(width) == .docked
    }

    /// Whether floating preview overlay is visible.
    func detachedPreviewShown(
        _ width: SettingsWidthClass
    ) -> Bool {
        previewForm(width) == .floating
    }

    /// Floating preview panel container (`SettingsFloatingPanel`,
    /// code review 2026-08-11).
    @ViewBuilder func detachedPreview(
        _ width: SettingsWidthClass
    ) -> some View {
        if detachedPreviewShown(width),
            let destination = model.destination
        {
            GeometryReader { geo in
                SettingsFloatingPanel(
                    model: model,
                    destination: destination,
                    bounds: geo.size,
                    close: { previewShown = false }
                )
            }
            .id(destination)
        }
    }

    /// Floating button offering to open preview on narrow widths.
    @ViewBuilder func showPreviewOffer(
        _ width: SettingsWidthClass
    ) -> some View {
        if previewForm(width) == .offer {
            Button {
                previewShown = true
            } label: {
                showPreviewLabel
            }
            .buttonStyle(.plain)
            .padding(.trailing, SettingsMetrics.paneInset)
            .padding(.bottom, 22)
        }
    }

    /// Preview offer chip view (owner 2026-08-11).
    private var showPreviewLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 11, weight: .semibold))
            Text(L("panel.show_preview", "Show preview"))
                .font(.callout)
        }
        .foregroundStyle(SettingsTheme.ink)
        .padding(.horizontal, ChipMetrics.padH)
        .padding(.vertical, ChipMetrics.padV)
        .background(
            ChipMetrics.shape
                .fill(SettingsTheme.card)
                .overlay(
                    ChipMetrics.shape.fill(
                        SettingsTheme.accent.opacity(
                            SettingsTheme.searchNoticeFillOpacity
                        )
                    )
                )
                .overlay(
                    ChipMetrics.shape.strokeBorder(
                        SettingsTheme.accent
                    )
                )
                .compositingGroup()
                .shadow(
                    color: .black.opacity(0.12),
                    radius: 8,
                    y: 3
                )
        )
        .contentShape(ChipMetrics.shape)
    }
}
