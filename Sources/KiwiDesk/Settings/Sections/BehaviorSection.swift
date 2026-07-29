import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Behavior (#68 §3.2): mouse-resize mode and
/// the general-purpose animation toggles + duration —
/// per-profile data, labeled as such by the sidebar group
/// (the old General tab presented them without any scope cue).
/// The Scrolling focus-shift toggle and its speed live with
/// the scrolling layout's own parameters (§3.5), not here.
struct BehaviorSection: View {
    @ObservedObject var model: SettingsModel
    /// macOS Reduce Motion forces animations off system-wide, so the
    /// whole Animations card reads as a control with no effect and
    /// greys out (#171). The engine honors the same flag in Core.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mouseSection
                animationsSection
                quitSection
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var mouseSection: some View {
        SettingsSection(SettingsCatalog.behavior.mouseCard) {
            SegmentedPicker(
                L(
                    "behavior.mouse.resize_action",
                    "Mouse resize action"
                ),
                selection: $model.config.settings
                    .mouseResize,
                options: [
                    (
                        L(
                            "behavior.mouse.resize_layout",
                            "Resize adjacent windows"
                        ),
                        MouseResizeMode.layout
                    ),
                    (
                        L(
                            "behavior.mouse.resize_snap_back",
                            "Snap back to slot"
                        ), .snapBack
                    ),
                ],
                help: L(
                    "behavior.mouse.resize_action.help",
                    "**Resize adjacent windows** — Dragging a "
                        + "window's edge resizes it and reflows "
                        + "its neighbours in the layout.\n**Snap "
                        + "back to slot** — The window resizes "
                        + "freely while you drag, then snaps back "
                        + "to its tiled size when you release."
                )
            )
            Toggle(
                L(
                    "behavior.mouse.follows_focus",
                    "Move mouse to focused window"
                ),
                isOn: $model.config.settings.mouse
                    .followsFocus
            )
        }
    }

    /// Master switch over the per-event animation toggles shown in
    /// this card. Derived, not a stored field (a second persisted
    /// on/off would re-create the removed global `enable_animations`
    /// and a drift hazard): on when any of the four animates; off
    /// silences all four; on restores their shipped defaults (space
    /// switch stays opt-in). Deliberately excludes `onScrolling` —
    /// the scrolling slide has its own toggle on the Scrolling card
    /// (linked below), so folding it in here would let the master
    /// read on with every visible box off, and silently revert a
    /// choice made on a card the user can't see from here.
    private var animationsMaster: Binding<Bool> {
        Binding(
            get: {
                let a = model.config.settings.animations
                return a.onSpaceChange || a.onWindowResize
                    || a.onWindowSwap || a.onRelayout
            },
            set: { on in
                let defaults = AnimationSettings()
                var a = model.config.settings.animations
                a.onSpaceChange = on ? defaults.onSpaceChange : false
                a.onWindowResize = on ? defaults.onWindowResize : false
                a.onWindowSwap = on ? defaults.onWindowSwap : false
                a.onRelayout = on ? defaults.onRelayout : false
                model.config.settings.animations = a
            }
        )
    }

    /// Explanation shown on the card's header `?` only while Reduce
    /// Motion forces the whole card off — a live anchor outside the
    /// dimmed subtree (#527), since a `GreyOut` kills every `?`
    /// inside it.
    private var reduceMotionHelp: String {
        L(
            "behavior.animations.reduce_motion.help",
            "System Settings ▸ Accessibility ▸ Reduce "
                + "Motion is on, so animations stay off "
                + "regardless of this setting."
        )
    }

    private var animationsSection: some View {
        // Reduce Motion greys the card CONTENT, not the header, so
        // the header `?` (below) stays a live #527 anchor. Nested
        // with the master gate: the non-compounding `GreyOut`
        // dims once (AutoGatedGroup.swift).
        SettingsSection(
            SettingsCatalog.behavior.animationsCard,
            help: reduceMotion ? reduceMotionHelp : nil
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ToggleRow(
                    label: L(
                        "behavior.animations.master",
                        "Animate windows"
                    ),
                    isOn: animationsMaster,
                    help: L(
                        "behavior.animations.master.help",
                        "The master switch for KiwiDesk's window "
                            + "animations. Off snaps windows into "
                            + "place instantly. Turning macOS "
                            + "System Settings ▸ Accessibility ▸ "
                            + "Reduce Motion on also keeps them off."
                    )
                )
                gatedAnimationControls
                    .modifier(
                        GreyOut(
                            active: !animationsMaster.wrappedValue
                        )
                    )
                CrossReferenceRow(
                    prose: L(
                        "behavior.animations.scrolling_xref",
                        "Scrolling-layout focus shifts have "
                            + "their own toggle and speed in"
                    ),
                    linkTitle: L(
                        "behavior.animations.scrolling_xref_link",
                        "Layout Defaults ▸ Scrolling"
                    ),
                    destination: .layoutDefaults
                )
            }
            .modifier(GreyOut(active: reduceMotion))
        }
    }

    /// The per-event toggles + duration the master switch gates.
    @ViewBuilder private var gatedAnimationControls: some View {
        Toggle(
            L(
                "behavior.animations.space_change",
                "Animate virtual space switches"
            ),
            isOn: $model.config.settings.animations.onSpaceChange
        )
        // Retires the entrance-only mental image (#207):
        // the transition is a coordinated out+in.
        Text(
            L(
                "behavior.animations.space_change.caption",
                "Windows slide out of the space you're "
                    + "leaving and into the one you're "
                    + "switching to."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        Toggle(
            L(
                "behavior.animations.window_resize",
                "Animate window resizes"
            ),
            isOn: $model.config.settings.animations.onWindowResize
        )
        Toggle(
            L(
                "behavior.animations.window_swap",
                "Animate window swaps"
            ),
            isOn: $model.config.settings.animations.onWindowSwap
        )
        Toggle(
            L(
                "behavior.animations.relayout",
                "Animate layout reflows"
            ),
            isOn: $model.config.settings.animations.onRelayout
        )
        Divider()
        durationRow
    }

    /// Stepper for the general animation duration
    /// (`animations.duration`; `animations.set_duration` Lua)
    /// — paces exactly the four toggles above (#51).
    private var durationRow: some View {
        StepperRow(
            label: L(
                "behavior.animations.duration",
                "Duration"
            ),
            value: $model.config.settings.animations
                .durationMS,
            in: 50...1000,
            step: 10,
            suffix: "ms"
        )
    }

    /// On quit (#281): the quit grid's density target
    /// (`quit.grid_target_depth`). Grid dimensions stay
    /// automatic (2×2…4×4); no layout picker while `grid` is
    /// the only strategy.
    private var quitSection: some View {
        SettingsSection(
            SettingsCatalog.behavior.quitCard,
            caption: L(
                "behavior.quit.caption",
                "Before KiwiDesk stops, it arranges managed "
                    + "windows on each display so their title "
                    + "bars remain reachable."
            )
        ) {
            StepperRow(
                label: L(
                    "behavior.quit.target_depth",
                    "Target windows per cell"
                ),
                value: $model.config.settings
                    .quitGridTargetDepth,
                in: QuitGridLayout.targetDepthRange,
                help: L(
                    "behavior.quit.target_depth.help",
                    "The grid adds a row and column when "
                        + "cells would exceed this target. It "
                        + "stays between 2×2 and 4×4; "
                        + "after 4×4, additional windows keep "
                        + "cascading in its cells."
                )
            )
            gridSummary
        }
    }

    /// Neutral live summary of the thresholds the current
    /// target produces: dimension grows past 4T and 9T.
    private var gridSummary: some View {
        let target = model.config.settings
            .quitGridTargetDepth
        return Text(
            L(
                "behavior.quit.summary",
                "2×2 up to %1$d windows · 3×3 up to %2$d · "
                    + "4×4 above %2$d",
                4 * target,
                9 * target
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
