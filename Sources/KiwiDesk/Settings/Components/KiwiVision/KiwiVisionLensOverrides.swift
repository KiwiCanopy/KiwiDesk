import KiwiDeskCore
import SwiftUI

/// A lens's own values for the Default cards (#2103 rulings
/// 23, 29, 46): Dim and blur, Stays clear and System appearance,
/// one override checkbox per ROW — a lens often changes the dim and
/// keeps the blur. An unchecked row reads "follows Default ·
/// <value>"; checking it seeds the lens with that value.
struct KiwiVisionLensOverrides: View {
    @ObservedObject var model: SettingsModel
    let lens: VisionLens

    private var plain: AppWideSettings { model.appWide }
    private var defaultName: String { KiwiVisionLensWords.defaultName }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(
                SettingsCatalog.kiwiVision.levelsCard.text,
                caption: KiwiVisionLensWords.followsCaption
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    dimRow
                    toggleRow(
                        SettingsCatalog.kiwiVision.blur.text,
                        \.blur,
                        plain.visionBlur
                    )
                    fadeDurationRow
                    fadeCurveRow
                }
            }
            SettingsSection(SettingsCatalog.kiwiVision.clearCard.text) {
                VStack(alignment: .leading, spacing: 4) {
                    toggleRow(
                        SettingsCatalog.kiwiVision.clearApp.text,
                        \.clearApp,
                        plain.visionClearApp
                    )
                    toggleRow(
                        SettingsCatalog.kiwiVision.clearWallpaper.text,
                        \.clearWallpaper,
                        plain.visionClearWallpaper
                    )
                }
            }
            SettingsSection(
                SettingsCatalog.kiwiVision.appearanceCard.text
            ) {
                appearanceRow
            }
        }
    }

    private func override<V>(
        _ path: WritableKeyPath<VisionLens.Overrides, V?>
    ) -> Binding<V?> {
        Binding(
            get: { lens.overrides[keyPath: path] },
            set: { value in
                model.updateLens(lens.name) {
                    $0.overrides[keyPath: path] = value
                }
            }
        )
    }

    private var dimRow: some View {
        let value = override(\.dim)
        let label = SettingsCatalog.kiwiVision.dim.text
        return OverrideChrome(
            isOn: overrideToggle(value, global: plain.visionDim),
            inherited: (label, Self.percent(plain.visionDim)),
            inheritsName: defaultName
        ) {
            SettingsRowShape(controlTrails: true) {
                SettingsRowLabel(label: label, help: nil)
            } control: {
                StepperRow(
                    label: label,
                    value: Binding(
                        get: { Int((value.wrappedValue ?? 0).rounded()) },
                        set: { value.wrappedValue = Double($0) }
                    ),
                    in: KiwiVisionLevelsCard.dimRange,
                    step: 5,
                    suffix: "%",
                    labelHidden: true
                )
            }
        }
    }

    private var fadeDurationRow: some View {
        let value = override(\.fadeDuration)
        let label = SettingsCatalog.kiwiVision.fadeDuration.text
        let global = plain.visionFadeDuration
        return OverrideChrome(
            isOn: overrideToggle(value, global: global),
            inherited: (label, Self.milliseconds(global)),
            inheritsName: defaultName
        ) {
            SettingsRowShape(controlTrails: true) {
                SettingsRowLabel(label: label, help: nil)
            } control: {
                StepperRow(
                    label: label,
                    value: Binding(
                        get: { value.wrappedValue ?? global },
                        set: { value.wrappedValue = $0 }
                    ),
                    in: AppWideSettings.visionFadeRange,
                    step: 50,
                    suffix: "ms",
                    labelHidden: true
                )
            }
        }
    }

    private var fadeCurveRow: some View {
        let value = override(\.fadeCurve)
        let label = SettingsCatalog.kiwiVision.fadeCurve.text
        let global = plain.visionFadeCurve
        let current = value.wrappedValue ?? global
        return OverrideChrome(
            isOn: overrideToggle(value, global: global),
            inherited: (label, KiwiVisionLevelsCard.curveTitle(global)),
            inheritsName: defaultName
        ) {
            DropdownRow(
                label: label,
                spokenValue: KiwiVisionLevelsCard.curveTitle(current),
                help: nil
            ) {
                Picker(
                    label,
                    selection: Binding(
                        get: { current },
                        set: { value.wrappedValue = $0 }
                    )
                ) {
                    ForEach(VisionFadeCurve.allCases, id: \.self) {
                        Text(KiwiVisionLevelsCard.curveTitle($0)).tag($0)
                    }
                }
            }
        }
    }

    private func toggleRow(
        _ label: String,
        _ path: WritableKeyPath<VisionLens.Overrides, Bool?>,
        _ global: Bool
    ) -> some View {
        let value = override(path)
        return OverrideChrome(
            isOn: overrideToggle(value, global: global),
            inherited: (label, Self.onOff(global)),
            inheritsName: defaultName
        ) {
            ToggleRow(
                label: label,
                isOn: Binding(
                    get: { value.wrappedValue ?? global },
                    set: { value.wrappedValue = $0 }
                )
            )
        }
    }

    private var appearanceRow: some View {
        let value = override(\.appearance)
        let label = SettingsCatalog.kiwiVision.appearance.text
        let current = value.wrappedValue ?? plain.visionAppearance
        return OverrideChrome(
            isOn: overrideToggle(value, global: plain.visionAppearance),
            inherited: (
                label, KiwiVisionAppearanceCard.title(plain.visionAppearance)
            ),
            inheritsName: defaultName
        ) {
            DropdownRow(
                label: label,
                spokenValue: KiwiVisionAppearanceCard.title(current),
                help: nil
            ) {
                Picker(
                    label,
                    selection: Binding(
                        get: { current },
                        set: { value.wrappedValue = $0 }
                    )
                ) {
                    Text(KiwiVisionAppearanceCard.title(.unchanged))
                        .tag(VisionAppearance.unchanged)
                    Divider()
                    ForEach(KiwiVisionAppearanceCard.switching, id: \.self) {
                        Text(KiwiVisionAppearanceCard.title($0)).tag($0)
                    }
                }
            }
        }
    }

    static func percent(_ dim: Double) -> String {
        L("kiwivision.lens.value.percent", "%1$d %%", Int(dim.rounded()))
    }

    static func milliseconds(_ ms: Int) -> String {
        L("kiwivision.lens.value.milliseconds", "%1$d ms", ms)
    }

    static func onOff(_ on: Bool) -> String {
        on ? KiwiVisionLensWords.on : KiwiVisionLensWords.off
    }
}
