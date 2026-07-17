import CoreGraphics
import Foundation

@testable import KiwiDeskCore

/// Fixtures that set *every* field to a non-default value. Shared
/// by the JSON round-trip in `AppBarTests` and the reflection
/// guards in `AppBarParityTests`, so there is a single mirror of
/// the field list to keep honest — `fixturesAreExhaustive` pins
/// that both fixtures still touch every field, which is what makes
/// the round-trip forget-proof (AGENTS.md §5). Lives in its own
/// file rather than being owned by one suite, symmetric with
/// `ReflectionParity.swift`.
enum AppBarFixtures {
    static func everyGlobalField() -> AppBarStyle {
        var style = AppBarStyle()
        style.position = .end
        style.thickness = 44
        style.tabBackground = .plain
        style.activeIndicator = .gap
        style.itemSize = 120
        style.itemGap = 3
        style.content = .name
        style.iconSource = .appFont
        style.groupAdjacentWindows = false
        style.fontSize = 15
        style.cornerRoundness = 5
        style.textColor = "#010101"
        style.boxColor = "#020202"
        style.activeTextColor = "#030303"
        style.activeBoxColor = "#040404"
        style.highlightColor = "#050505"
        style.hoverColor = "#060606"
        style.hoverTextColor = "#070707"
        style.backgroundColor = "#080808"
        style.groupBadgeColor = "#090909"
        style.groupBadgeTextColor = "#0A0A0A"
        return style
    }

    static func everyOverrideField() -> LayoutAppBar {
        var bar = LayoutAppBar()
        bar.enabled = false
        bar.position = .start
        bar.thickness = 50
        bar.tabBackground = .boxed
        bar.activeIndicator = .ring
        bar.itemSize = 88
        bar.itemGap = 9
        bar.content = .iconAndName
        bar.iconSource = .appImage
        bar.groupAdjacentWindows = true
        bar.fontSize = 20
        bar.cornerRoundness = 12
        bar.textColor = "#111111"
        bar.boxColor = "#222222"
        bar.activeTextColor = "#333333"
        bar.activeBoxColor = "#444444"
        bar.highlightColor = "#555555"
        bar.hoverColor = "#666666"
        bar.hoverTextColor = "#777777"
        bar.backgroundColor = "#888888"
        bar.groupBadgeColor = "#999999"
        bar.groupBadgeTextColor = "#AAAAAA"
        return bar
    }
}
