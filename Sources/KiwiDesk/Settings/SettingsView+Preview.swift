import KiwiDeskCore
import SwiftUI

/// The shell's half of the responsive preview (#678 turn 17a):
/// which of the panel's three forms the measured band gets, and
/// the two surfaces the narrow ones need. Split from
/// `SettingsView` at the §2.1 ceiling; the panel's own
/// capability question (`panelOffered`) stays there, beside the
/// destination it reads.
extension SettingsView {
    /// The area's preview form at this width, or `nil` where
    /// the area offers no preview at all. The capability
    /// question and the width question are answered in that
    /// order, once — every site below reads this rather than
    /// re-testing the band.
    func previewForm(
        _ width: SettingsWidthClass
    ) -> SettingsPreviewForm? {
        guard panelOffered else { return nil }
        return SettingsPreviewForm.at(width, shown: previewShown)
    }

    /// The panel keeps a column of its own — the only form that
    /// takes layout space, and so the only one the save pill's
    /// centring offset has to answer to.
    func panelDocked(_ width: SettingsWidthClass) -> Bool {
        previewForm(width) == .docked
    }

    /// The detached card is on screen: the band's default,
    /// unless the user has said otherwise this mount.
    func detachedPreviewShown(
        _ width: SettingsWidthClass
    ) -> Bool {
        previewForm(width) == .floating
    }

    /// The card. A `GeometryReader` rather than an alignment,
    /// because the card's own height, its resting corner and
    /// its travel limits are all arithmetic over the content
    /// area's size — the clamp is what keeps a dragged preview
    /// retrievable at 720 pt.
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
        }
    }

    /// "Show preview" — the offer that replaces the card once
    /// the window is too narrow to open it unasked. Present
    /// whenever the area HAS a preview and none is on screen,
    /// so the capability never disappears silently: 17a drops
    /// the preview's column, never the preview.
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
            // Clears the docked save bar's own row when the
            // draft has summoned one, and sits on the pill's
            // line otherwise — the offer is chrome for the
            // content, never something stacked on the footer.
            .padding(.bottom, 22)
        }
    }

    /// The offer's chip (owner, on device 2026-08-11): a
    /// bordered button read as transparent over the content it
    /// floats on, so this is an opaque `card` plane with the
    /// ACCENT as its edge — the same colour that marks the
    /// profile chip in the header, which is where the owner
    /// pointed.
    ///
    /// The accent is on the border, never the words: it marks
    /// an affordance, not a value, and the glyph beside the
    /// label is the non-hue half of the same signal, so the
    /// chip still reads as a control with hue removed. Drawn
    /// as a plain-styled chip rather than a `.bordered` button
    /// because a bordered one takes the tint on its LABEL,
    /// which is exactly the pairing the seal exists to
    /// prevent.
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
