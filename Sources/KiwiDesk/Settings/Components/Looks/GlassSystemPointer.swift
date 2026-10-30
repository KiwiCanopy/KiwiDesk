import KiwiDeskCore
import SwiftUI

/// Where the glass's see-through level lives: macOS's own Liquid
/// Glass slider, which KiwiDesk follows rather than overrides
/// (`docs/design-decisions.md` ▸ One Liquid Glass switch). The
/// path quotes the Appearance pane's loctable.
struct GlassSystemPointer: View {
    var body: some View {
        let (leading, trailing) = CrossReferenceRow.split(Self.prose)
        LinkedCaption(
            leading: leading,
            linkTitle: Self.pathLabel,
            trailing: trailing,
            navigate: { MacSettingRead.openPane(Self.appearancePane) }
        )
    }

    static var pathLabel: String {
        L(
            "colors.liquid_glass.system.path",
            "System Settings ▸ Appearance ▸ Liquid Glass"
        )
    }

    static var prose: String {
        L(
            "colors.liquid_glass.system",
            "The glass's transparency follows %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    /// System Settings ▸ Appearance; no anchor for the slider,
    /// which moves between releases.
    static let appearancePane = URL(
        string: "x-apple.systempreferences:"
            + "com.apple.Appearance-Settings.extension"
    )!
}
