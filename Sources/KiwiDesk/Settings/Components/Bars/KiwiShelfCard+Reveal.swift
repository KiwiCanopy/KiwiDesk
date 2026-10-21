import KiwiDeskCore
import SwiftUI

/// How an Auto or Hidden bar comes onto its empty edge (#2497):
/// in the Show group under Each bar, greyed with its sentence while
/// no bar ever hides, as `BarsGates` answers it (owner ruling,
/// 2026-10-21).
extension KiwiShelfCard {
    @ViewBuilder var revealStyleRow: some View {
        let reason = BarsGates(
            settings: model.config.settings,
            guiManaged: model.guiManaged
        ).inertReason(for: .kiwishelf(.revealStyle))
        SegmentedPicker(
            L("kiwishelf.reveal_style.label", "Reveal"),
            selection: shelf.revealStyle,
            options: AppBarOptions.revealStyle.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.reveal_style.label.help",
                "How a hidden bar appears: \u{201C}%1$@\u{201D} brings "
                    + "the whole bar in from the screen edge; "
                    + "\u{201C}%2$@\u{201D} grows it out of its mark, "
                    + "or wipes across the boxes of a \u{201C}%5$@"
                    + "\u{201D} background; \u{201C}%3$@\u{201D} "
                    + "stretches it out of the mark along the edge, "
                    + "then deepens it, or springs each box out of the "
                    + "mark; \u{201C}%4$@\u{201D} fades it in where it "
                    + "stands. A bar with no mark grows or unfolds "
                    + "from the middle of the screen edge.",
                L("kiwishelf.reveal_style.slide", "Slide"),
                L("kiwishelf.reveal_style.grow", "Grow"),
                L("kiwishelf.reveal_style.unfold", "Unfold"),
                L("kiwishelf.reveal_style.fade", "Fade"),
                L("app_bar.background_style.boxed", "Boxed")
            )
        )
        .modifier(GreyOut(active: reason != nil))
        .searchAnchored(SettingsCatalog.bars.kiwishelfRevealStyle)
        if let reason {
            Text(BarsGateHelp.sentence(for: reason))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
