import KiwiDeskCore
import SwiftUI

/// KiwiVision ▸ Stays clear (#2103 ruling 18): what the haze
/// leaves alone besides the focused window. A card of its own,
/// since Dim and blur set how strong the haze is and these set
/// where it reaches.
struct KiwiVisionClearCard: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.kiwiVision.clearCard,
            caption: KiwiVisionCopy.appliesAtOnce
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(KiwiVisionRowOrder.clear, id: \.id) { key in
                    row(key)
                    if let reason = reason(for: key) {
                        KiwiVisionCopy.reason(
                            KiwiVisionGates.sentence(for: reason)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder private func row(_ key: SettingKey) -> some View {
        switch key {
        case .kiwiVision(.clearWallpaper): wallpaperRow
        default:
            let _ = assertionFailure(
                "unrendered KiwiVision census key: \(key.id)"
            )
            EmptyView()
        }
    }

    private func reason(
        for key: SettingKey
    ) -> KiwiVisionGates.InertReason? {
        KiwiVisionGates(guiManaged: model.guiManaged).inertReason(for: key)
    }

    private var wallpaperRow: some View {
        ToggleRow(
            label: SettingsCatalog.kiwiVision.clearWallpaper.text,
            isOn: Binding(
                get: { model.appWide.visionClearWallpaper },
                set: { on in
                    model.setAppWide { $0.visionClearWallpaper = on }
                }
            ),
            help: L(
                "kiwivision.clear_wallpaper.help",
                "Only the windows behind the focused one are dimmed "
                    + "and blurred; the wallpaper around them and in the "
                    + "gaps between them stays as it is."
            ),
            disabled: reason(for: .kiwiVision(.clearWallpaper)) != nil
        )
        .searchAnchored(SettingsCatalog.kiwiVision.clearWallpaper)
    }
}
