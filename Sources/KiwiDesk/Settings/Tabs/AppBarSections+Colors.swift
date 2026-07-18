import KiwiDeskCore
import SwiftUI

/// The App Bar color rows (#374), split from
/// `AppBarSections.swift` for the file ceiling — the
/// `SpaceBarColorsSection` sibling. The disclosure's `@State`
/// stays in `GlobalAppBarSection` (extensions can't hold
/// state); only the row builders live here.
extension GlobalAppBarSection {
    // The three the preview strip reflects most, kept inline.
    @ViewBuilder var inlineColors: some View {
        HexColorField(
            label: L("app_bar.color.box", "Box"),
            hex: $style.boxColor
        )
        HexColorField(
            label: L("app_bar.color.active_box", "Active box"),
            hex: $style.activeBoxColor
        )
        HexColorField(
            label: L("app_bar.color.highlight", "Highlight"),
            hex: $style.highlightColor
        )
    }

    // The remaining palette, behind the disclosure.
    @ViewBuilder var advancedColors: some View {
        Group {
            HexColorField(
                label: L("app_bar.color.text", "Text"),
                hex: $style.textColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.active_text",
                    "Active text"
                ),
                hex: $style.activeTextColor
            )
            HexColorField(
                label: L("app_bar.color.hover", "Hover"),
                hex: $style.hoverColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.hover_text",
                    "Hover text"
                ),
                hex: $style.hoverTextColor
            )
        }
        Group {
            HexColorField(
                label: L(
                    "app_bar.color.background",
                    "Background"
                ),
                hex: $style.backgroundColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.group_badge",
                    "Group badge"
                ),
                hex: $style.groupBadgeColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.badge_text",
                    "Badge text"
                ),
                hex: $style.groupBadgeTextColor
            )
        }
    }
}
