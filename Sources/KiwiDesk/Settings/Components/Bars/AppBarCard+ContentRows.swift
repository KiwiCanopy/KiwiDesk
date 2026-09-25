import KiwiDeskCore
import SwiftUI

/// Content configuration rows for AppBarCard: content, title cap, icon style.
extension AppBarCard {
    /// The content picker; inert on a vertical edge, which is set
    /// on the KiwiShelf card, so the reason is drawn beside it
    /// rather than left to the dim (#815, #1517).
    @ViewBuilder var contentRow: some View {
        SegmentedPicker(
            L("app_bar.content.label", "Content"),
            selection: style.content,
            options: AppBarOptions.content.map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                active: gates.everyShownBarVertical,
                help: contentVerticalReason
            )
        )
        if gates.everyShownBarVertical,
            GateReasonPlacement.owesInlineReason(
                .appBar(.appBarContent)
            )
        {
            BarNoteRow(text: contentVerticalReason)
        }
    }

    private var contentVerticalReason: String {
        L(
            "app_bar.content.vertical_only.shelf",
            "Left and right edges show icons only. The edge is set "
                + "under \u{201C}%1$@\u{201D} in %2$@.",
            L("kiwishelf.edge.label", "Position"),
            L("bars.switch.kiwishelf", "KiwiShelf")
        )
    }

    /// Window title character length cap (#901, #937).
    var titleCapRow: some View {
        StepperRow(
            label: L("app_bar.title_cap", "Title length"),
            value: style.titleCap,
            in: AppBarStyle.titleCapRange,
            help: L(
                "app_bar.title_cap.help",
                "How many characters of a window's title an "
                    + "item shows before it is shortened. "
                    + "Grouped windows show their app's name "
                    + "instead, which is never shortened."
            )
        )
    }

}
