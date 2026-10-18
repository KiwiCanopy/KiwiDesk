import KiwiDeskCore
import SwiftUI

/// The selected lens's page (#2103 rulings 29, 46–54): its header,
/// Apps and Other apps, its own values for the Default
/// cards, then — under "Every lens" — Never dimmed, which writes at
/// once. Everything above that heading waits for the page's Save.
/// Greyed where `init.lua` owns the config.
struct KiwiVisionLensPage: View {
    @ObservedObject var model: SettingsModel
    let lens: VisionLens
    /// The header's chord recorder, as Shortcuts holds its own.
    @StateObject private var coordinator = RecorderCoordinator()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                KiwiVisionLensHeader(model: model, lens: lens.name)
                KiwiVisionLensAppsCard(model: model, lens: lens)
                KiwiVisionLensOtherAppsCard(model: model, lens: lens)
                KiwiVisionLensOverrides(model: model, lens: lens)
            }
            .disabled(reason != nil)
            if let reason {
                KiwiVisionCopy.reason(KiwiVisionGates.sentence(for: reason))
            }
            KiwiVisionEveryLensHeading()
            KiwiVisionNeverDimmedCard(model: model)
        }
        .environment(\.keybindingLayerName, KeyLayer.defaultName)
        .environment(\.hyperKeyIsOff, model.appWide.hyperKey == nil)
        .environment(
            \.disabledSystemShortcuts,
            model.disabledSystemShortcuts()
        )
        .environmentObject(coordinator)
        .onAppear {
            // Suspend hotkeys while a chord is captured (#213).
            coordinator.onArmedChange = { [model] armed in
                model.setRecorderArmed(armed)
            }
        }
        .onChange(of: lens.name) { _, _ in coordinator.invalidate() }
        .onDisappear { coordinator.invalidate() }
    }

    private var reason: KiwiVisionGates.InertReason? {
        KiwiVisionGates(guiManaged: model.guiManaged)
            .inertReason(for: .kiwiVision(.lenses))
    }
}

/// The rule naming what follows as every lens's (ruling 47).
struct KiwiVisionEveryLensHeading: View {
    var body: some View {
        HStack(spacing: 8) {
            Text(KiwiVisionLensWords.everyLens)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(SettingsTheme.hairline)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }
}
