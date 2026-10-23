import KiwiDeskCore
import SwiftUI

/// How an Auto or Hidden bar comes onto its empty edge (#2497):
/// in the Show group under Each bar, greyed with its sentence while
/// no bar ever hides, as `BarsGates` answers it (owner ruling,
/// 2026-10-21).
extension KiwiShelfCard {
    @ViewBuilder var revealStyleRow: some View {
        let gates = BarsGates(
            settings: model.config.settings,
            guiManaged: model.guiManaged
        )
        let reason = gates.inertReason(for: .kiwishelf(.revealStyle))
        SegmentedPicker(
            L("kiwishelf.reveal_style.label", "Reveal"),
            selection: shelf.revealStyle,
            options: AppBarOptions.revealStyle.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.reveal_style.label.help",
                "How a hidden bar appears: \u{201C}%1$@\u{201D} brings "
                    + "the whole bar in from the screen edge; "
                    + "\u{201C}%2$@\u{201D} grows it out of its mark, "
                    + "and unfolds on a \u{201C}%5$@\u{201D} "
                    + "background; \u{201C}%3$@\u{201D} "
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
        if reason == nil, gates.growPlaysAsUnfold {
            note(BarsGateHelp.growPlaysAsUnfold)
        }
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
        // One sentence for the picker and the reveal's own length,
        // which grey together; the expand plays regardless.
        if let reason {
            caption(reason)
        }
    }

    /// `value` stepped over 0 and `band`, so a step from the floor
    /// lands on 0 and never on a blink in between — Core's
    /// `AnimationSettings.stepped`.
    static func instantOr(
        _ value: Binding<Int>,
        band: ClosedRange<Int>,
        step: Int
    ) -> Binding<Int> {
        Binding(
            get: { value.wrappedValue },
            set: { new in
                value.wrappedValue = AnimationSettings.stepped(
                    new,
                    from: value.wrappedValue,
                    band: band,
                    step: step
                )
            }
        )
    }

    /// Whether no bar hides, so the reveal's rows take no input.
    private var revealInert: Bool {
        BarsGates(
            settings: model.config.settings,
            guiManaged: model.guiManaged
        ).inertReason(for: .colours(.animationsRevealDurationMS)) != nil
    }

    /// A reason sentence under what it greys, outside the grey.
    func caption(_ reason: BarsGates.InertReason) -> some View {
        note(BarsGateHelp.sentence(for: reason))
    }

    /// A caption-weight line under a row.
    func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The reveal's and the expand's lengths (owner ruling,
    /// 2026-10-21), in the Durations drawer: the reveal's greys with
    /// the picker, the expand's only while its switch is off.
    @ViewBuilder func durationRow(_ key: SettingKey) -> some View {
        let animations = $model.config.settings.animations
        let children = SettingsCatalog.bars.kiwishelfDurations.children
        switch key {
        case .colours(.animationsRevealDurationMS):
            StepperRow(
                label: children.revealDuration.text,
                value: Self.instantOr(
                    animations.revealDurationMS,
                    band: AnimationSettings.revealDurationBand,
                    step: AnimationSettings.revealDurationStep
                ),
                in: 0...AnimationSettings.revealDurationBand.upperBound,
                step: AnimationSettings.revealDurationStep,
                suffix: "ms",
                help: L(
                    "kiwishelf.reveal_duration.help",
                    "How long a hidden bar takes to appear, whichever "
                        + "way it reveals; it leaves a little quicker. "
                        + "0 makes it instant."
                )
            )
            .modifier(GreyOut(active: revealInert))
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
                value: Self.instantOr(
                    animations.expandDurationMS,
                    band: AnimationSettings.expandDurationBand,
                    step: 50
                ),
                in: 0...AnimationSettings.expandDurationBand.upperBound,
                step: 50,
                suffix: "ms",
                help: L(
                    "kiwishelf.expand_duration.help",
                    "How long the bars take to grow out of each "
                        + "other, shrink back, fade and glide into "
                        + "place. 0 makes it instant."
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
