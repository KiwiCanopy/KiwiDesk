import KiwiDeskCore
import SwiftUI

/// The Space switch rows (#2524): Slide, Show the Space or None,
/// and the slide's pace beneath. App-wide (#1741), written at once
/// like the Desktop cue's row, above the window master and outside
/// Reduce Motion's grey. The caption follows the selection.
extension MotionCard {
    /// Why the Space switch rows are inert: `init.lua` owns the
    /// config, so an app-wide row it does not store is not the
    /// GUI's to write (#1741).
    var spaceTransitionLuaOwned: Bool { !model.guiManaged }

    @ViewBuilder var spaceTransitionRow: some View {
        let style = model.appWide.spaceTransition
        VStack(alignment: .leading, spacing: 4) {
            DropdownRow(
                label: Self.spaceTransitionLabel,
                spokenValue: Self.spaceTransitionTitle(style)
            ) {
                Picker(
                    Self.spaceTransitionLabel,
                    selection: Binding(
                        get: { model.appWide.spaceTransition },
                        set: { pick in
                            model.setAppWide { $0.spaceTransition = pick }
                        }
                    )
                ) {
                    ForEach(SpaceTransition.allCases, id: \.self) {
                        Text(Self.spaceTransitionTitle($0)).tag($0)
                    }
                }
                .neutralMenuLabel()
            }
            .disabled(spaceTransitionLuaOwned)
            .searchAnchored(SettingsCatalog.colors.spaceTransition)
            Text(spaceTransitionCaption(style))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if spaceTransitionLuaOwned {
                Text(GeneralGateHelp.sentence(for: .luaOwned))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var spaceSlideDurationRow: some View {
        StepperRow(
            label: L(
                "animations.space_slide_duration",
                "Slide duration"
            ),
            value: Binding(
                get: { model.appWide.spaceSlideDuration },
                set: { ms in
                    model.setAppWide { $0.spaceSlideDuration = ms }
                }
            ),
            in: AppWideSettings.spaceSlideDurationRange,
            step: 10,
            suffix: "ms",
            help: L(
                "animations.space_slide_duration.help",
                "How long the plates take to slide to the Space "
                    + "you're switching to. A longer duration is "
                    + "slower."
            )
        )
        .searchAnchored(SettingsCatalog.colors.spaceSlideDuration)
    }

    /// Closes the Space switch group: both rows are app-wide on a
    /// profile's page, so it says so, as KiwiVision's immediate
    /// cards do (#1741); the divider parts it from the window
    /// master, which does not reach it (#1932, #2524).
    @ViewBuilder var spaceSwitchGroupEnd: some View {
        Text(KiwiVisionCopy.appliesAtOnce)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
        Divider()
    }

    /// Greys the duration while no slide plays — off Slide, or
    /// under Reduce Motion — a wiring predicate on Core's one
    /// fallback, beside the census's Lua gate.
    var spaceSlideDurationInert: Bool {
        spaceTransitionLuaOwned
            || model.appWide.spaceTransition
                .drawn(reduceMotion: reduceMotion) != .slide
    }

    static var spaceTransitionLabel: String {
        L("animations.space_transition", "Space switches")
    }

    /// The option's title, drawn and spoken alike.
    static func spaceTransitionTitle(_ style: SpaceTransition) -> String {
        switch style {
        case .slide:
            return L("animations.space_transition.slide", "Slide")
        case .show:
            return L(
                "animations.space_transition.show",
                "Show the Space"
            )
        case .none:
            return L("animations.space_transition.none", "None")
        }
    }

    /// What the selection does; under Reduce Motion, Slide shows
    /// the Space instead, which its caption says.
    func spaceTransitionCaption(_ style: SpaceTransition) -> String {
        let drawn = style.drawn(reduceMotion: reduceMotion)
        switch style {
        case .slide where drawn != .slide:
            return L(
                "animations.space_transition.slide.reduced",
                "Your windows slide away as the Space you're "
                    + "switching to slides in. Reduce Motion is on, "
                    + "so the Space is shown instead."
            )
        case .slide:
            return L(
                "animations.space_transition.slide.caption",
                "Your windows slide away as the Space you're "
                    + "switching to slides in."
            )
        case .show:
            return L(
                "animations.space_transition.show.caption",
                "The screen changes at once, and for a moment shows "
                    + "the Space you arrived on and its layout — "
                    + "never over a full-screen app or a "
                    + "presentation."
            )
        case .none:
            return L(
                "animations.space_transition.none.caption",
                "The screen changes at once."
            )
        }
    }
}
