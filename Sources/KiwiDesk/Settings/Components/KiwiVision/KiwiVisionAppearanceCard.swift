import KiwiDeskCore
import SwiftUI

/// KiwiVision ▸ System appearance (#2103 ruling 7). Its own card,
/// so it never reads as a second General ▸ Appearance, which
/// themes KiwiDesk's windows alone.
struct KiwiVisionAppearanceCard: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.kiwiVision.appearanceCard,
            caption: KiwiVisionCopy.appliesAtOnce
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(KiwiVisionRowOrder.appearance, id: \.id) { _ in
                    appearanceRow
                    if let reason = reason {
                        KiwiVisionCopy.reason(
                            KiwiVisionGates.sentence(for: reason)
                        )
                    }
                }
            }
        }
    }

    private var reason: KiwiVisionGates.InertReason? {
        KiwiVisionGates(guiManaged: model.guiManaged)
            .inertReason(for: .kiwiVision(.appearance))
    }

    private var appearanceRow: some View {
        let selection = model.appWide.visionAppearance
        return DropdownRow(
            label: SettingsCatalog.kiwiVision.appearance.text,
            spokenValue: Self.title(selection),
            help: help
        ) {
            Picker(
                SettingsCatalog.kiwiVision.appearance.text,
                selection: Binding(
                    get: { model.appWide.visionAppearance },
                    set: { value in
                        model.setAppWide { $0.visionAppearance = value }
                    }
                )
            ) {
                Text(Self.title(.unchanged)).tag(VisionAppearance.unchanged)
                Divider()
                ForEach(Self.switching, id: \.self) { value in
                    Text(Self.title(value)).tag(value)
                }
            }
            .disabled(reason != nil)
        }
        .searchAnchored(SettingsCatalog.kiwiVision.appearance)
    }

    /// The Lua order after `unchanged` (ruling 7).
    static let switching: [VisionAppearance] = [.opposite, .dark, .light]

    static func title(_ value: VisionAppearance) -> String {
        switch value {
        case .unchanged:
            return L("kiwivision.appearance.unchanged", "Unchanged")
        case .opposite:
            return L(
                "kiwivision.appearance.opposite",
                "Opposite of System"
            )
        case .dark: return L("general.appearance.dark", "Dark")
        case .light: return L("general.appearance.light", "Light")
        }
    }

    /// The option's own label is interpolated (#818).
    private var help: String {
        L(
            "kiwivision.appearance.help",
            "Switches macOS — every app, not only KiwiDesk — to this "
                + "appearance when KiwiVision turns on, and back when "
                + "it turns off. %1$@ picks whichever appearance macOS "
                + "is not showing. A change you make yourself while "
                + "KiwiVision is on is kept.",
            Self.title(.opposite)
        )
    }
}
