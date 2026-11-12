import KiwiDeskCore
import SwiftUI

/// The speed preset (#3238): Off · Slow · Default · Fast, Settings'
/// one pace control, drawn by the Animations card and by Simple
/// alike. The segment shown is derived from the app-wide lengths,
/// none for Custom; a pick writes at once, in every profile. While
/// macOS Reduce Motion is on, Off shows picked and the picker takes
/// no input, the card's own box saying why.
struct AnimationSpeedRow: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.accessibilityReduceMotion) private var systemReduced

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.appWide.animationReduceMotion, !systemReduced {
                WarningBox(text: Self.offWarning) {
                    Button(Self.turnOnTitle) {
                        write { $0.animationReduceMotion = false }
                    }
                    .settingsActionButton()
                    .disabled(!model.guiManaged)
                }
            }
            SegmentedPicker(
                SettingsCatalog.colors.animationSpeed.text,
                spokenValue: spoken,
                selection: selection,
                options: AnimationPacePreset.allCases.map {
                    (Self.title(of: $0), Optional($0))
                },
                help: Self.help
            )
            .disabled(systemReduced || !model.guiManaged)
            .searchAnchored(SettingsCatalog.colors.animationSpeed)
            if shown == nil {
                Text(Self.customReadout)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
            if model.guiManaged {
                LiveSettingCaption()
            } else {
                // The census's Lua gate (#1741), drawn inline.
                Text(GeneralGateHelp.sentence(for: .luaOwned))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The segment the lengths read as; macOS Reduce Motion shows
    /// Off, since nothing plays.
    private var shown: AnimationPacePreset? {
        systemReduced ? .off : AnimationPacePreset.current(of: model.appWide)
    }

    private var selection: Binding<AnimationPacePreset?> {
        Binding(
            get: { shown },
            set: { pick in
                guard let pick else { return }
                write { $0.applyPace(pick) }
            }
        )
    }

    /// The row's one app-wide write, beside its one live caption.
    private func write(_ edit: (inout AppWideSettings) -> Void) {
        model.setAppWide { edit(&$0) }
    }

    private var spoken: String {
        shown.map(Self.title(of:)) ?? Self.customReadout
    }

    static func title(of preset: AnimationPacePreset) -> String {
        switch preset {
        case .off: L("behavior.animations.speed.off", "Off")
        case .slow: L("behavior.animations.speed.slow", "Slow")
        case .standard: L("behavior.animations.speed.default", "Default")
        case .fast: L("behavior.animations.speed.fast", "Fast")
        }
    }

    static var help: String {
        L(
            "behavior.animations.speed.help",
            "How fast KiwiDesk animates, in every profile: windows, "
                + "scrolling, the bars, Space switches and KiwiVision. "
                + "%1$@ stops those animations and keeps each "
                + "profile's switches.",
            title(of: .off)
        )
    }

    static var customReadout: String {
        L(
            "behavior.animations.speed.custom",
            "Custom durations. Pick a speed to replace them."
        )
    }

    static var offWarning: String {
        L(
            "behavior.animations.speed.off_warning",
            "Animations are off in every profile."
        )
    }

    static var turnOnTitle: String {
        L("behavior.animations.speed.turn_on", "Turn On")
    }
}
