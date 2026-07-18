import CoreGraphics
import Foundation

@testable import KiwiDeskCore

/// A fixture that sets *every* `SpaceBarStyle` field to a
/// non-default value, shared by the JSON round-trip and the
/// reflection guards in `SpaceBarParityTests` — the same single
/// mirror-to-keep-honest shape as `AppBarFixtures` (AGENTS.md
/// §5).
enum SpaceBarFixtures {
    static func everyField() -> SpaceBarStyle {
        var style = SpaceBarStyle()
        style.enabled = true
        style.edge = .bottom
        style.alignment = .end
        style.thickness = 44
        style.boxSize = 120
        style.boxGap = 3
        style.fontSize = 15
        style.glyphCap = 8
        style.iconSource = .appFont
        style.tabBackground = .plain
        style.activeIndicator = .gap
        style.cornerRoundness = 5
        style.showFrontApp = true
        style.hideEmpty = true
        style.springDelay = 1000
        style.textColor = "#010101"
        style.activeTextColor = "#020202"
        style.focusedItemColor = "#030303"
        style.hoverColor = "#040404"
        style.hoverTextColor = "#050505"
        style.boxColor = "#060606"
        style.activeBoxColor = "#070707"
        style.highlightColor = "#080808"
        style.backgroundColor = "#090909"
        style.groupBadgeColor = "#0A0A0A"
        style.groupBadgeTextColor = "#0B0B0B"
        return style
    }
}
