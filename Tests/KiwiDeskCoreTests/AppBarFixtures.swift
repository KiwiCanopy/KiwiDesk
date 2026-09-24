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
        style.activeIndicator = .gap
        style.content = .title
        style.titleCap = 40
        style.iconSource = .appFont
        style.groupAdjacentWindows = false
        style.dimFactor = 0.3
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
        bar.activeIndicator = .outline
        bar.content = .iconAndTitle
        bar.titleCap = 60
        bar.iconSource = .appImage
        bar.groupAdjacentWindows = true
        bar.dimFactor = 0.5
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

    /// Every `KiwiShelf` field off its default (`KiwiShelfParityTests`).
    static func everyShelfField() -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.edge = .left
        shelf.alignment = .end
        shelf.order = .appsFirst
        shelf.share = 60
        shelf.thickness = 44
        shelf.outerMargin = 4
        shelf.innerMargin = 6
        shelf.backgroundStyle = .boxed
        shelf.liquidGlass = false
        shelf.backgroundFit = .full
        shelf.cornerRoundness = 5
        shelf.itemGap = 3
        shelf.fontSize = 15
        return shelf
    }
}
