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
        style.glyphCap = 8
        style.frontAppTitleCap = 40
        style.activeIndicator = .edgeMark
        style.activeDimFactor = 0.7
        style.showFrontApp = true
        style.hideEmpty = true
        style.stickyBadge = false
        style.springDelay = 1000
        style.focusedItemColor = "#030303"
        return style
    }
}
