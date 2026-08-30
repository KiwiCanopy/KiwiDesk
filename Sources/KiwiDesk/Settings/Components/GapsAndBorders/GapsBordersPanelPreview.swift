import KiwiDeskCore
import SwiftUI

/// Gaps & Borders visual preview panel (#678).
struct GapsBordersPanelPreview: View {
    @ObservedObject var model: SettingsModel

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            group(SettingsCatalog.gapsAndBorders.gapsCard) {
                GapsDiagram(
                    outer: settings.gapsGlobal.outer,
                    inner: settings.gapsGlobal.inner
                )
            }
            group(SettingsCatalog.gapsAndBorders.focusBorder) {
                FocusBorderPreview(
                    style: settings.borderStyle,
                    sticky: settings.stickyStyle
                )
            }
            group(SettingsCatalog.gapsAndBorders.dragCard) {
                dragPair
            }
            Text(
                L(
                    "panel.caption.draft",
                    "Shows your draft, not the saved profile."
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }

    /// Ghost and drop zone drag previews (#231).
    private var dragPair: some View {
        VStack(alignment: .leading, spacing: 10) {
            labelled(SettingsCatalog.gapsAndBorders.dragGhost) {
                DragVisualPreview(
                    visual: settings.dragGhost,
                    cornerRadius: settings.dragCornerRadius
                )
            }
            labelled(SettingsCatalog.gapsAndBorders.dragDropZone) {
                DragVisualPreview(
                    visual: settings.dragDropZone,
                    cornerRadius: settings.dragCornerRadius
                )
            }
        }
    }

    private func group<C: View>(
        _ control: SettingsControl,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(control.text)
                .font(
                    .system(size: 10, weight: .semibold)
                        .monospaced()
                )
                .kerning(1.2)
                .textCase(.uppercase)
                .foregroundStyle(SettingsTheme.ink3)
            content()
        }
    }

    private func labelled<C: View>(
        _ control: SettingsControl,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(control.text)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
            content()
        }
    }
}
