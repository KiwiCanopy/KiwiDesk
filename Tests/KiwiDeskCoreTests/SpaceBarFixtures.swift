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
        // Non-default: the bar ships enabled (QA 2026-07-19).
        style.enabled = false
        style.edge = .bottom
        style.alignment = .end
        style.thickness = 44
        style.boxSize = 120
        style.boxGap = 3
        style.fontSize = 15
        style.glyphCap = 8
        style.iconSource = .appFont
        style.tabBackground = .plain
        style.liquidGlass = true
        style.tabBackgroundFit = .full
        style.activeIndicator = .gap
        style.cornerRoundness = 5
        style.dimFactor = 0.3
        style.activeDimFactor = 0.7
        style.showFrontApp = true
        style.hideEmpty = true
        style.stickyBadge = false
        style.springDelay = 1000
        style.itemColor = "#010101"
        style.activeItemColor = "#020202"
        style.focusedItemColor = "#030303"
        style.hoverFillColor = "#040404"
        style.hoverItemColor = "#050505"
        style.fillColor = "#060606"
        style.highlightColor = "#080808"
        style.groupBadgeColor = "#0A0A0A"
        style.groupBadgeTextColor = "#0B0B0B"
        return style
    }
}
