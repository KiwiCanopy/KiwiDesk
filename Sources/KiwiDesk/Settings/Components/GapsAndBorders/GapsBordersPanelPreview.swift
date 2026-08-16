import KiwiDeskCore
import SwiftUI

/// The Gaps & Borders panel content (#678 redesign spec): the
/// pictures this area always had, recycled whole — the gap
/// miniature with its legend, the focus-ring pair, and the drag
/// visuals — now stacked in the panel column instead of leading
/// their cards. Deliberately NOT a new fused desktop scene: each
/// picture is an existing renderer with its own guard surface,
/// and the redesign rule is recycle, never rebuild beside one.
///
/// Three things it did not do until the owner looked at it on
/// screen (2026-08-16), all of them the same failure — a panel
/// that answers for a whole area has to answer for the WHOLE
/// area:
///
/// 1. **The drag visuals are a pair.** It drew the ghost alone,
///    while the area's own editor draws ghost and drop zone in
///    twin columns because #231 says they are edited by
///    comparison. One of a pair is the half that cannot be
///    compared.
/// 2. **The sticky mark was nowhere**, though this area owns the
///    Sticky windows card and its toggle. A switch whose effect
///    the preview never shows is a switch the reader has to save
///    and go look for.
/// 3. **Nothing was labelled.** Three pictures stacked without
///    headers read as one run-on illustration; with them, each
///    is an answer to a card below.
///
/// The headers reuse the area's own catalog declarations rather
/// than minting titles, so a picture and the card it answers for
/// can never come to disagree about what they are called.
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
                    // This area owns the mark's switch, so this
                    // is the mount that shows it.
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

    /// Ghost beside drop zone, each under its own subheading —
    /// the #231 twin columns, at panel width. Stacked rather
    /// than side by side: the panel is 392 pt less its insets,
    /// and two drag mocks side by side there are too small to
    /// compare, which is the one thing the pairing is for.
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

    /// A picture under the name of the card it answers for.
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

    /// The quieter inner heading, for the two halves of one
    /// picture — a second mono-caps line would compete with the
    /// group header above it.
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
