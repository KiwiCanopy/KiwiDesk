import KiwiDeskCore
import SwiftUI

/// A lens's own values for the Focused window cards (#2103 rulings
/// 23, 29, 46): Dim and blur, Stays clear and System appearance,
/// one override checkbox per ROW — a lens often changes the dim and
/// keeps the blur. An unchecked row reads "follows Focused window ·
/// <value>"; checking it seeds the lens with that value.
struct KiwiVisionLensOverrides: View {
    @ObservedObject var model: SettingsModel
    let lens: VisionLens

    private var plain: AppWideSettings { model.appWide }
    private var focused: String { KiwiVisionLensWords.focusedWindow }

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
            inheritsName: focused
        ) {
            SettingsRowShape {
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

    private func toggleRow(
        _ label: String,
        _ path: WritableKeyPath<VisionLens.Overrides, Bool?>,
        _ global: Bool
    ) -> some View {
        let value = override(path)
        return OverrideChrome(
            isOn: overrideToggle(value, global: global),
            inherited: (label, Self.onOff(global)),
            inheritsName: focused
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
            inheritsName: focused
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

    static func onOff(_ on: Bool) -> String {
        on ? KiwiVisionLensWords.on : KiwiVisionLensWords.off
    }
}
