import KiwiDeskCore
import SwiftUI

/// Where the bars sit along the edge (#1517): alignment for a lone
/// bar, both as one run, or each bar on its own edge.
extension KiwiShelfCard {
    @ViewBuilder var alignmentRow: some View {
        SegmentedPicker(
            L("kiwishelf.alignment.label", "Alignment"),
            selection: shelf.alignment,
            options: AppBarOptions.alignment.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.alignment.label.help",
                "Where the bars sit along the edge — a lone bar, "
                    + "both as one run, or each bar on its own edge. "
                    + "\u{201C}%1$@\u{201D} and \u{201C}%2$@\u{201D} "
                    + "follow the edge, so on a left edge the start "
                    + "is the top.",
                L("app_bar.alignment.start", "Start"),
                L("app_bar.alignment.end", "End")
            )
        )
        if let note = alignmentNote {
            BarNoteRow(text: note)
        }
    }

    /// The accepted trade-off, said where it is chosen: once the
    /// App Bar joins the Space Bar into one run, a Space Bar
    /// aligned anywhere but the run's own end moves — Core's own
    /// verdict names the alignment that holds it still (#1517).
    private var alignmentNote: String? {
        guard model.config.settings.bothBarsCanShow,
            gates.bothBarsReason == nil,
            let steady = ShelfArrangement.spaceBarMoves(
                shelf: shelf.wrappedValue
            )
        else { return nil }
        return L(
            "kiwishelf.alignment.note",
            "When the App Bar shows, the two bars join into one "
                + "run, so the Space Bar moves. \u{201C}%1$@\u{201D} "
                + "keeps it still.",
            steady == .start
                ? L("app_bar.alignment.start", "Start")
                : L("app_bar.alignment.end", "End")
        )
    }
}
