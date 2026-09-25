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
        // Non-default: the App Bar ships Edge mark (#1517).
        style.activeIndicator = .outline
        style.content = .title
        style.titleCap = 40
        style.groupAdjacentWindows = false
        return style
    }

    static func everyOverrideField() -> LayoutAppBar {
        var bar = LayoutAppBar()
        bar.enabled = false
        bar.activeIndicator = .edgeMark
        bar.content = .iconAndTitle
        bar.titleCap = 60
        bar.groupAdjacentWindows = true
        return bar
    }

    /// Every `KiwiShelf` field off its default (`KiwiShelfParityTests`).
    static func everyShelfField() -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.edge = .left
        shelf.alignment = .end
        shelf.order = .appsFirst
        shelf.minimum = 60
        shelf.thickness = 44
        shelf.outerMargin = 4
        shelf.innerMargin = 6
        shelf.backgroundStyle = .boxed
        shelf.liquidGlass = false
        shelf.backgroundFit = .full
        shelf.cornerRoundness = 5
        shelf.itemGap = 3
        shelf.fontSize = 15
        shelf.iconSource = .appFont
        shelf.dimFactor = 0.3
        shelf.itemColor = "#010101"
        shelf.fillColor = "#020202"
        shelf.activeItemColor = "#030303"
        shelf.highlightColor = "#050505"
        shelf.hoverFillColor = "#060606"
        shelf.hoverItemColor = "#070707"
        shelf.groupBadgeColor = "#090909"
        shelf.groupBadgeTextColor = "#0A0A0A"
        return shelf
    }
}
