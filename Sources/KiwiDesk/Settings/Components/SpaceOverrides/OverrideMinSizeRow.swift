import KiwiDeskCore
import SwiftUI

/// A Space's own minimum window size (#2422): one W × H override
/// for whatever layout the Space uses, prefilled from the value it
/// follows when checked. Unchecking is the reset.
struct OverrideMinSizeRow: View {
    @Binding var value: MinSize?
    /// The layout value the Space follows while unchecked.
    let followed: MinSize
    /// What it follows: the Space's layout where that layout stands
    /// apart, else the Minimum window size setting.
    let followedName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            OverrideChrome(
                isOn: overrideToggle($value, global: followed),
                inherited: (Self.label, size(followed)),
                help: Self.help,
                subject: Self.label,
                inheritsName: followedName) {
                SettingsRowShape(controlTrails: true) {
                    Text(Self.label).lineLimit(1)
                } control: {
                    MinSizeFields(
                        name: Self.axisName,
                        width: Int(current.width),
                        height: Int(current.height),
                        base: { Int(followed[$0]) },
                        set: { axis, v in
                            var size = current
                            size[axis] = CGFloat(v)
                            value = size
                        }
                    )
                }
            }
            if value != nil {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, SettingsMetrics.overrideRowInset)
            }
        }
    }

    static var label: String {
        L("layout_defaults.min_window_size", "Minimum window size")
    }

    static var help: String {
        L(
            "space_override.min_size.help",
            "Windows in this Space never tile smaller than this, "
                + "whatever its layout. The value stays with this "
                + "Space when it moves to another screen."
        )
    }

    private var current: MinSize { value ?? followed }

    private var caption: String {
        L(
            "space_override.min_size.caption",
            "Overrides %1$@ · %2$@. Stays with this Space on any "
                + "screen.",
            followedName,
            size(followed)
        )
    }

    private func size(_ size: MinSize) -> String {
        SettingsValueReadout.minSize(size)
    }

    private static func axisName(_ axis: MinSizeAxis) -> String {
        axis == .width
            ? L("space_override.min_size.width", "Width, this Space")
            : L("space_override.min_size.height", "Height, this Space")
    }
}
