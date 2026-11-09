import KiwiDeskCore
import SwiftUI

/// KiwiVision ▸ Maximize (#3064), a card of its own (owner,
/// 2026-11-09): what the focused window fills. Gated like every
/// app-wide KiwiVision row.
struct KiwiVisionMaximizeCard: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.kiwiVision.maximizeCard,
            caption: KiwiVisionCopy.appliesAtOnce
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(KiwiVisionRowOrder.maximize, id: \.id) { key in
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
        case .kiwiVision(.maximize):
            KiwiVisionMaximizeRow(
                model: model,
                disabled: reason(for: key) != nil
            )
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
}

/// Maximize the focused window: four short peers, so a segmented
/// picker on the Default page; a lens's row keeps the override
/// chrome's menu (`docs/ui-patterns.md`).
struct KiwiVisionMaximizeRow: View {
    @ObservedObject var model: SettingsModel
    var disabled: Bool

    var body: some View {
        SegmentedPicker(
            SettingsCatalog.kiwiVision.focusedFill.text,
            selection: Binding(
                get: { model.appWide.visionMaximize },
                set: { fill in
                    model.setAppWide { $0.visionMaximize = fill }
                }
            ),
            options: Self.options,
            help: Self.help
        )
        .disabled(disabled)
        .searchAnchored(SettingsCatalog.kiwiVision.focusedFill)
    }

    /// Off first, then the whole screen, then its two axes: the
    /// declared order.
    static let order = VisionMaximize.allCases

    static var options: [(title: String, value: VisionMaximize)] {
        order.map { (title($0), $0) }
    }

    static func title(_ fill: VisionMaximize) -> String {
        switch fill {
        case .off: L("kiwivision.maximize.off", "Off")
        case .full: L("kiwivision.maximize.full", "Full")
        case .height: L("kiwivision.maximize.height", "Height")
        case .width: L("kiwivision.maximize.width", "Width")
        }
    }

    static var help: String {
        L(
            "kiwivision.maximize.help",
            "While KiwiVision is on, the focused window fills the "
                + "screen, or its full height or width at the shares "
                + "set in %1$@. Focus another window and it takes the "
                + "room. Monocle and floating windows keep their size.",
            SettingsDestination.layoutDefaults.title
        )
    }
}
