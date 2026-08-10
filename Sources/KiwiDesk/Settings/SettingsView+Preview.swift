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
            Button(L("panel.show_preview", "Show preview")) {
                previewShown = true
            }
            .settingsActionButton()
            .padding(.trailing, SettingsMetrics.paneInset)
            // Clears the docked save bar's own row when the
            // draft has summoned one, and sits on the pill's
            // line otherwise — the offer is chrome for the
            // content, never something stacked on the footer.
            .padding(.bottom, 22)
        }
    }
}
