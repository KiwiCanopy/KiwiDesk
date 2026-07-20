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
        style.edge = .bottom
        style.alignment = .end
        style.thickness = 44
        style.tabBackground = .plain
        style.liquidGlass = true
        style.tabBackgroundFit = .full
        style.activeIndicator = .gap
        style.boxSize = 120
        style.boxGap = 3
        style.content = .name
        style.iconSource = .appFont
        style.groupAdjacentWindows = false
        style.fontSize = 15
        style.cornerRoundness = 5
        style.itemColor = "#010101"
        style.fillColor = "#020202"
        style.activeItemColor = "#030303"
        style.highlightColor = "#050505"
        style.hoverFillColor = "#060606"
        style.hoverItemColor = "#070707"
        style.groupBadgeColor = "#090909"
        style.groupBadgeTextColor = "#0A0A0A"
        return style
    }

    static func everyOverrideField() -> LayoutAppBar {
        var bar = LayoutAppBar()
        bar.enabled = false
        bar.edge = .right
        bar.alignment = .start
        bar.thickness = 50
        bar.tabBackground = .boxed
        // Differs from the global fixture (true) so resolve parity
        // sees the override write.
        bar.liquidGlass = false
        // The global fixture uses .full, so the override must
        // differ for the resolve parity to see the write.
        bar.tabBackgroundFit = .hug
        bar.activeIndicator = .outline
        bar.boxSize = 88
        bar.boxGap = 9
        bar.content = .iconAndName
        bar.iconSource = .appImage
        bar.groupAdjacentWindows = true
        bar.fontSize = 20
        bar.cornerRoundness = 12
        bar.itemColor = "#111111"
        bar.fillColor = "#222222"
        bar.activeItemColor = "#333333"
        bar.highlightColor = "#555555"
        bar.hoverFillColor = "#666666"
        bar.hoverItemColor = "#777777"
        bar.groupBadgeColor = "#999999"
        bar.groupBadgeTextColor = "#AAAAAA"
        return bar
    }
}
