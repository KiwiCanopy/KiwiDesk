import KiwiDeskCore
import SwiftUI

extension SpaceOverrideRows {
    /// The Space's own Maximize Height, Maximize Width and Maximize
    /// from (#3090), above the layout rows since they survive a
    /// layout switch; each its own override, never greyed. An unset
    /// row follows the Space's screen shape.
    @ViewBuilder
    var maximizeRows: some View {
        shareRow(.height)
        shareRow(.width)
        anchorRow
        Text(maximizeCaption)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SettingsMetrics.overrideRowInset)
    }

    private func shareRow(_ axis: MaximizeAxis) -> some View {
        let label = Self.maximizeLabel(axis)
        let value = Binding<Double?>(
            get: { g.maximize.shareOverride[space]?[axis] },
            set: {
                model.config.settings.maximize.setShareOverride(
                    $0,
                    for: axis,
                    in: space
                )
            }
        )
        let followed = followedShare(axis)
        return OverrideChrome(
            isOn: overrideToggle(value, global: followed),
            inherited: (label, MaximizeSharePopUp.glyph(followed)),
            subject: label,
            inheritsName: screenShape.map(MaximizeShapeText.name),
            inheritedLine: screenShape == nil ? eachScreen : nil
        ) {
            SettingsRowShape(controlTrails: true) {
                Text(label).lineLimit(1)
            } control: {
                MaximizeSharePopUp(
                    value: overrideValue(value, global: followed),
                    label: label,
                    column: label
                )
            }
        }
    }

    private var anchorRow: some View {
        let label = L("layout_defaults.maximize.anchor", "Maximize from")
        let followed =
            screenShape.map { g.maximize.anchor[$0] }
            ?? MaximizeSettings.defaultAnchor(.widescreen)
        return OverridePickerRow(
            label: label,
            value: $model.config.settings.maximize.anchorOverride[space],
            global: followed,
            options: MaximizeAnchor.allCases.map {
                ($0, MaximizeCard.anchorName($0))
            },
            inheritsName: screenShape.map(MaximizeShapeText.name),
            inheritedLine: screenShape == nil ? eachScreen : nil
        )
    }

    /// The share an unset row follows: its screen shape's, or the
    /// widescreen row's where the Space has no single screen.
    private func followedShare(_ axis: MaximizeAxis) -> Double {
        g.maximize.share(for: axis, on: screenShape ?? .widescreen)
    }

    /// The shape of the one screen this Space lays out on: its pin,
    /// else the only screen connected; nil where it may move.
    var screenShape: ScreenShape? {
        switch model.spacePlacement(of: space) {
        case .pinned(let display)?:
            return ScreenShape.of(display)
        default:
            return model.displays.count == 1
                ? model.displays.first.map(ScreenShape.of) : nil
        }
    }

    private var eachScreen: String {
        L(
            "space_override.maximize.each_screen",
            "follows each screen's shape"
        )
    }

    /// The verb names, which fit the override column where the
    /// Layout Defaults labels cut off.
    static func maximizeLabel(_ axis: MaximizeAxis) -> String {
        switch axis {
        case .height: KeybindingCatalog.maximizeHeight.displayLabel()
        case .width: KeybindingCatalog.maximizeWidth.displayLabel()
        }
    }

    /// One caption for the three rows; on Monocle it says they apply
    /// to the Space's floating windows, since a tiled one there
    /// refuses a Height or Width press.
    private var maximizeCaption: String {
        if mode == .monocle {
            return L(
                "space_override.maximize.caption.monocle",
                "On Monocle these apply to floating windows: a tiled "
                    + "window already fills the screen. The values stay "
                    + "with this Space on any screen."
            )
        }
        return L(
            "space_override.maximize.caption",
            "How wide %1$@ and how tall %2$@ make a window in this "
                + "Space, and where it grows from. The values stay with "
                + "this Space on any screen.",
            Self.maximizeLabel(.height),
            Self.maximizeLabel(.width)
        )
    }
}
