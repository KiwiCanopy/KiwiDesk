import KiwiDeskCore
import SwiftUI

/// Where the glass's see-through level lives: macOS's own Liquid
/// Glass slider, which KiwiDesk follows rather than overrides
/// (ui-designer, 2026-10-30). The path quotes the Appearance
/// pane's loctable (config-vocabulary.md ▸ quote Apple verbatim).
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
            "How see-through the glass is follows %1$@.",
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
