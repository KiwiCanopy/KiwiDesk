import AppKit
import KiwiDeskCore
import SwiftUI

/// General's two app-wide rows (#1741): written the moment they
/// change, like every other row on the card they sit on.
extension GeneralSection {
    /// The refusal cue's audible half (#1255). Previews on
    /// switch-on, the way macOS's own alert-sound picker does.
    @ViewBuilder var refusalSoundRow: some View {
        Toggle(
            L(
                "general.refusal_sound",
                "Play the alert sound when an action can't apply"
            ),
            isOn: Binding(
                get: { model.appWide.refusalSound },
                set: { on in
                    model.setAppWide { $0.refusalSound = on }
                    if on { NSSound.beep() }
                }
            )
        )
        .disabled(appWideReason(.refusalSound) != nil)
        appWideReasonText(.refusalSound)
        Text(
            L(
                "general.refusal_sound.help",
                "A blocked action always shows a message on "
                    + "the window — at a size limit, or where "
                    + "the layout has nothing to resize. This "
                    + "adds the system alert sound to it."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// The quit grid's density target (`quit.grid_target_depth`,
    /// #281). Grid dimensions stay automatic
    /// (`QuitGridLayout.shape`, #1709).
    @ViewBuilder var quitPileDepthRow: some View {
        StepperRow(
            label: L(
                "general.quit_pile_depth",
                "Windows per pile on quit"
            ),
            value: Binding(
                get: { model.appWide.quitGridTargetDepth },
                set: { depth in
                    model.setAppWide { $0.quitGridTargetDepth = depth }
                }
            ),
            in: QuitGridLayout.targetDepthRange,
            help: L(
                "general.quit_pile_depth.help",
                "Windows tile the display until they "
                    + "outnumber the grid's cells, then pile "
                    + "up in them; the grid grows, up to 4×4, "
                    + "when a pile would pass this number."
            )
        )
        .disabled(appWideReason(.quitGridTargetDepth) != nil)
        Text(
            L(
                "general.quit_pile_depth.caption",
                "Before KiwiDesk stops, it arranges managed "
                    + "windows on each display so their title "
                    + "bars remain reachable."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        appWideReasonText(.quitGridTargetDepth)
    }

    /// The grey and its sentence come from the one resolver
    /// (`GeneralGates`), never a predicate re-derived here.
    private func appWideReason(
        _ key: GeneralKey
    ) -> GeneralGates.InertReason? {
        model.generalGates.inertReason(for: .general(key))
    }

    @ViewBuilder private func appWideReasonText(
        _ key: GeneralKey
    ) -> some View {
        if let reason = appWideReason(key) {
            Text(GeneralGateHelp.sentence(for: reason))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
        }
    }
}
