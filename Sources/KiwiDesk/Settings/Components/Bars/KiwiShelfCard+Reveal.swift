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
        SettingsDisclosure(
            SettingsCatalog.bars.kiwishelfDurations,
            isExpanded: $durationsExpanded,
            scrollHoisted: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(BarsRowOrder.kiwishelfDurations, id: \.id) {
                    durationRow($0)
                }
            }
            .padding(.top, 8)
        }
        .modifier(GreyOut(active: reason != nil))
        // One sentence for the group: the three grey together.
        if let reason {
            caption(reason)
        }
    }

    /// A reason sentence under what it greys, outside the grey.
    func caption(_ reason: BarsGates.InertReason) -> some View {
        Text(BarsGateHelp.sentence(for: reason))
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The reveal's and the expand's lengths (owner ruling,
    /// 2026-10-21), in the Durations drawer.
    @ViewBuilder func durationRow(_ key: SettingKey) -> some View {
        let animations = $model.config.settings.animations
        let children = SettingsCatalog.bars.kiwishelfDurations.children
        switch key {
        case .colours(.animationsRevealDurationMS):
            StepperRow(
                label: children.revealDuration.text,
                value: animations.revealDurationMS,
                in: AnimationSettings.revealDurationBand,
                step: AnimationSettings.revealDurationStep,
                suffix: "ms",
                help: L(
                    "kiwishelf.reveal_duration.help",
                    "How long a hidden bar takes to appear, whichever "
                        + "way it reveals; it leaves a little quicker."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfDurations.children
                    .revealDuration
            )
        default:
            let reason = BarsGates(
                settings: model.config.settings,
                guiManaged: model.guiManaged
            ).inertReason(for: .colours(.animationsExpandDurationMS))
            StepperRow(
                label: children.expandDuration.text,
                value: animations.expandDurationMS,
                in: AnimationSettings.expandDurationBand,
                step: 50,
                suffix: "ms",
                help: L(
                    "kiwishelf.expand_duration.help",
                    "How long the bars take to grow out of each "
                        + "other, shrink back, fade and glide into "
                        + "place."
                )
            )
            .modifier(GreyOut(active: reason == .expandOff))
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfDurations.children
                    .expandDuration
            )
            if reason == .expandOff {
                caption(.expandOff)
            }
        }
    }
}
