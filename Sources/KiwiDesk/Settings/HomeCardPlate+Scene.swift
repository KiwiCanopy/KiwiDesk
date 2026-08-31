import KiwiDeskCore
import SwiftUI

/// Gaps & Borders plate scene tile for Home cards (#786).
struct HomeCardGapsTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        let outer = settings.gapsGlobal.outer
        let inner = settings.gapsGlobal.inner
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    palette?.frame
                        ?? SettingsTheme.ink2.opacity(0.3)
                )
            VStack(spacing: mini(inner.vertical)) {
                HStack(spacing: mini(inner.horizontal)) {
                    pane(focused: true)
                    pane(focused: false)
                }
                HStack(spacing: mini(inner.horizontal)) {
                    pane(focused: false)
                    pane(focused: false)
                }
            }
            .padding(.top, 2 + mini(outer.top))
            .padding(.bottom, 2 + mini(outer.bottom))
            .padding(.leading, 2 + mini(outer.left))
            .padding(.trailing, 2 + mini(outer.right))
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mini(_ real: CGFloat) -> CGFloat {
        GapPreviewScale.mini(real)
    }

    /// Renders individual pane with focus border scaling
    /// (`FocusBorderPreview`).
    @ViewBuilder
    private func pane(focused: Bool) -> some View {
        let border = settings.borderStyle
        let ringed =
            border.enabled
            && (focused || border.unfocusedEnabled)
        RoundedRectangle(cornerRadius: 4)
            .fill(palette?.base ?? SettingsTheme.previewPlate)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        palette?.ghostFill
                            ?? SettingsTheme.ink2.opacity(0.15)
                    )
            )
            .overlay {
                if ringed {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            focused
                                ? palette?.accent
                                    ?? SettingsTheme.accent
                                : palette?.ghostStroke
                                    ?? SettingsTheme.ink2
                                    .opacity(0.5),
                            lineWidth: strokeWidth
                        )
                }
            }
    }

    /// Scaled border stroke width (`BorderPreviewScale`).
    private var strokeWidth: CGFloat {
        BorderPreviewScale.width(
            settings.borderStyle.clampedWidth,
            to: 1...3
        )
    }
}
