import KiwiDeskCore
import SwiftUI

/// KiwiVision ▸ Maximize the focused window (#3064): four short
/// peers, so a segmented picker on the Default page; a lens's row
/// keeps the override chrome's menu (`docs/ui-patterns.md`).
struct KiwiVisionMaximizeRow: View {
    @ObservedObject var model: SettingsModel
    var disabled: Bool

    var body: some View {
        SegmentedPicker(
            SettingsCatalog.kiwiVision.maximize.text,
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
        .searchAnchored(SettingsCatalog.kiwiVision.maximize)
    }

    /// Off first, then the whole screen, then its two axes.
    static let order: [VisionMaximize] = [.off, .full, .height, .width]

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
